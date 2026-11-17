# frozen_string_literal: true

# Which field the Materials / Medium and Nationality filters read: the cleaned-up terms (rake index:normalise, Normalise::IndexWriter)
# when the core has them, else the source field as before (a core built only by collections:index, as in CI, has no terms).
#
# Asked of Solr once, when the catalog's filters are set up (the app starts); after the first index:normalise, restart the app.
# Never asked in tests (force sets the answer) and never fatal: no answer means the source field.
module NormalisedTerms
  FIELDS = { "material_ssim" => "material_term_ssim", "nationality_ssim" => "nationality_term_ssim" }.freeze

  class << self
    # The field a filter mapped to `source` facets on
    def field_for(source)
      term = FIELDS[source]
      term && present?(term) ? term : source
    end

    # For tests: { "material_term_ssim" => true } (nil: forget, and do not ask Solr)
    def force(answers) = @answers = answers&.dup

    private

    def present?(field)
      @answers ||= Rails.env.test? ? {} : nil
      return @answers.fetch(field, false) if @answers

      (@probed ||= {}).fetch(field) { @probed[field] = probe(field) }
    end

    def probe(field)
      response = Blacklight.default_index.connection.get("select", params: { q: "*:*", fq: "#{field}:[* TO *]", rows: 0, wt: "json" })
      response.dig("response", "numFound").to_i.positive?
    rescue StandardError => e
      Rails.logger.warn("Normalised #{field} check unavailable: #{e.class}")
      false
    end
  end
end
