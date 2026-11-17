# frozen_string_literal: true

# The short description under a card of the Browse page and the home page's Explore sections, worked out from the records the card opens:
# "Includes photographs, letters. Held in the Grainger Museum Collection and the University Art Collection." Nothing is written by hand
# and nothing is invented: it is the two commonest kinds of record (left out for a card that is a kind itself) and the two commonest
# collections, from one facet request. The wording around the facts is a placeholder (config/locales/card_layout.en.yml).
module CardDescription
  LIMIT = 4 # facet values asked for, so the values left out (noise) do not leave the lists short

  # filter: the Solr filter that opens the card's records; kinds: whether to list the kinds of record; earliest: the card is the earliest period
  def self.for(filter:, kinds: true, earliest: false)
    fields = [ (ExploreEntryPoints::CLASSIFICATION_FIELD if kinds), ExploreEntryPoints::COLLECTION_FIELD ].compact
    response = Discovery.search(q: "*:*", rows: 0, facet: true, fq: [ filter ], "facet.field": fields, "facet.limit": LIMIT, "facet.mincount": 1, "facet.sort": "count")
    facets = response.dig("facet_counts", "facet_fields") || {}
    parts = []
    parts << I18n.t("card_description.earliest") if earliest
    kinds_found = kinds ? top(facets[ExploreEntryPoints::CLASSIFICATION_FIELD]).map(&:downcase) : []
    parts << I18n.t("card_description.includes", kinds: kinds_found.join(", ")) if kinds_found.any?
    collections = top(facets[ExploreEntryPoints::COLLECTION_FIELD])
    parts << I18n.t("card_description.held_in", collections: collections.to_sentence) if collections.any?
    parts.join(" ")
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable
    ""
  end

  def self.top(pairs, limit = 2) = pairs.to_a.each_slice(2).map(&:first).reject { |value| Browse.noise?(value) || value == "[other]" }.first(limit)

  private_class_method :top
end
