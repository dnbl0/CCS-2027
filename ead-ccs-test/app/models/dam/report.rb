# frozen_string_literal: true

require "csv"

module Dam
  # What the DAM sync matched (rake dam:report): the live assets whose accession number no record in the index has, and counts.
  class Report
    HEADERS = %w[dam_id accession_number collection filename format_type].freeze
    # The records carrying DAM fields. The digest is hex, so a term range over 0-9a-f finds every one (an exists query,
    # [* TO *], needs docValues or norms, which a string field here does not have).
    DIGEST_PRESENT = 'dam_digest_ssi:["0" TO "g"]'

    def initialize(solr:)
      @solr = solr
    end

    def write_unmatched(path)
      CSV.open(path, "w") do |csv|
        csv << HEADERS
        unmatched.find_each { |asset| csv << HEADERS.map { |column| asset.public_send(column) } }
      end
    end

    def summary
      live = DamAsset.live
      with_accession = live.where.not(accession_number: nil)
      matched = with_accession.distinct.pluck(:accession_number) & index_accessions.to_a
      by_collection = unmatched.reorder(nil).group(:collection).count.sort_by { |_name, count| -count }.first(8)
      <<~TEXT
        DAM assets: #{DamAsset.count} (#{live.count} live, #{DamAsset.where.not(deleted_at: nil).count} deleted)
        Live assets with an accession number: #{with_accession.count}
        Accession numbers that match a record: #{matched.size} of #{with_accession.distinct.count(:accession_number)}
        Records with DAM data in the index: #{@solr.get('select', params: { q: DIGEST_PRESENT, rows: 0, wt: 'json' }).dig('response', 'numFound')}
        Unmatched assets: #{unmatched.count}#{by_collection.map { |name, count| "\n  #{name || '(no collection)'}: #{count}" }.join}
      TEXT
    end

    private

    def unmatched
      @unmatched ||= DamAsset.live.where.not(accession_number: nil).where.not(accession_number: index_accessions.to_a).order(:accession_number)
    end

    def index_accessions
      @index_accessions ||= begin
        accessions = Set.new
        cursor = "*"
        loop do
          response = @solr.get("select", params: { q: "accession_number_ssim:[* TO *]", fl: "id,accession_number_ssim", sort: "id asc",
                                                   rows: 5_000, cursorMark: cursor, wt: "json" })
          response.dig("response", "docs").each { |doc| accessions.merge(Array(doc["accession_number_ssim"])) }
          break if response["nextCursorMark"] == cursor

          cursor = response["nextCursorMark"]
        end
        accessions
      end
    end
  end
end
