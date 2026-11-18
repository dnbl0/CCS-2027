# frozen_string_literal: true

require "csv"

module Normalise
  # rake index:normalise: the cleaned-up filter terms into the writable core (DAM_SOLR_URL), as Solr atomic updates, for the
  # records whose terms changed only (normalise_digest_ssi):
  #
  #   material_term_ssim     from material_ssim (Normalise::Materials): the Materials / Medium filter
  #   nationality_term_ssim  from nationality_ssim (Normalise::Nationalities): the Nationality filter
  #
  # The filters read these fields once the core has them (NormalisedTerms). Nationality values that name no nationality on the list
  # are left out, counted, and written to a CSV for review.
  class IndexWriter
    FIELDS = %w[material_term_ssim nationality_term_ssim normalise_digest_ssi].freeze
    QUERY = "material_ssim:[* TO *] OR nationality_ssim:[* TO *] OR normalise_digest_ssi:[* TO *]"

    Report = Struct.new(:seen, :updated, :material_terms, :nationality_terms, :unparsed, keyword_init: true) do
      def to_s
        [ "#{seen} records read, #{updated} updated",
          "#{material_terms.size} material terms (most used: #{top(material_terms)})",
          "#{nationality_terms.size} nationalities (most used: #{top(nationality_terms)})",
          "#{unparsed.size} nationality values name no nationality on the list (#{unparsed.values.sum} records)" ].join("\n")
      end

      def top(tally) = tally.sort_by { |term, count| [ -count, term ] }.first(8).map { |term, count| "#{term} #{count}" }.join(", ")
    end

    def initialize(solr:, unparsed_csv: Rails.root.join("tmp/nationality_unparsed.csv"))
      @solr = solr
      @unparsed_csv = unparsed_csv
    end

    def write
      report = Report.new(seen: 0, updated: 0, material_terms: Hash.new(0), nationality_terms: Hash.new(0), unparsed: Hash.new(0))
      changes = []
      WritableCore.each_batch(@solr, q: QUERY, fl: "id,material_ssim,nationality_ssim,normalise_digest_ssi") do |docs|
        docs.each do |doc|
          report.seen += 1
          fields = fields_for(doc, report)
          changes << { "id" => doc["id"] }.merge(fields) unless fields["normalise_digest_ssi"] == doc["normalise_digest_ssi"]
        end
      end
      report.updated = WritableCore.update(@solr, changes)
      write_unparsed(report.unparsed)
      report
    end

    private

    def fields_for(doc, report)
      materials = Materials.terms(doc["material_ssim"])
      nationalities = Array(doc["nationality_ssim"]).flat_map do |value|
        terms = Nationalities.terms(value)
        report.unparsed[value] += 1 if terms.empty? && value.present?
        terms
      end.uniq
      materials.each { |term| report.material_terms[term] += 1 }
      nationalities.each { |term| report.nationality_terms[term] += 1 }
      fields = { "material_term_ssim" => materials.presence, "nationality_term_ssim" => nationalities.presence }
      digest = Digest::SHA256.hexdigest(fields.to_json) if fields.values.any?
      fields.merge("normalise_digest_ssi" => digest)
    end

    def write_unparsed(unparsed)
      FileUtils.mkdir_p(File.dirname(@unparsed_csv))
      CSV.open(@unparsed_csv, "w") do |csv|
        csv << %w[nationality_value records]
        unparsed.sort_by { |value, count| [ -count, value ] }.each { |row| csv << row }
      end
    end
  end
end
