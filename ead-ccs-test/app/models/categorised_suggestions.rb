# frozen_string_literal: true

# Suggestions as you type that say what they are: a creator, a collection, an object type or a title containing the typed text, each
# opening the search it names (a creator or type filter, the whole collection, a title search). One Solr request for facet values
# (facet.contains, ignoring case, rows=0), so it works on today's index: no suggester configuration, reindex or reload. Blacklight's
# own suggester (the "suggest" handler) is still asked when none of these match (CatalogController#suggest).
#
# A better index-side version would be a Solr suggester per field with the field's name as its payload (solr/conf, a change for the
# dev team who run the shared index); this needs none.
module CategorisedSuggestions
  Suggestion = Data.define(:value, :kind, :query)

  # field => the kind's key under nexus_ccs.suggestions.kinds, in the order the list shows them
  FIELDS = { "creator_ssim" => :creator, "collection_ssim" => :collection, "object_type_ssim" => :object_type, "title_si" => :title }.freeze
  PER_KIND = 3
  MAX = 10
  MIN_LENGTH = 2
  MAX_LENGTH = 100

  module_function

  # Up to MAX suggestions for the text, grouped by kind; [] for text too short or too long, or when Solr cannot answer
  def for(text)
    text = text.to_s.squish
    return [] if text.length < MIN_LENGTH || text.length > MAX_LENGTH

    response = Blacklight.default_index.search(params: params(text))
    FIELDS.flat_map { |field, kind| values(response, field).map { |value| Suggestion.new(value: value, kind: label(kind), query: query(field, value)) } }
          .first(MAX)
  rescue StandardError => error
    Discovery.log_failure("Suggestions", error)
    []
  end

  def params(text)
    { q: "*:*", defType: "lucene", rows: 0, facet: true, "facet.field": FIELDS.keys, "facet.contains": text, "facet.contains.ignoreCase": true,
      "facet.limit": PER_KIND, "facet.mincount": 1, "facet.sort": "count", spellcheck: false, hl: false, stats: false, wt: "json" }
  end

  def values(response, field)
    list = response.dig("facet_counts", "facet_fields", field) || []
    list.each_slice(2).map(&:first).map(&:to_s).compact_blank.first(PER_KIND)
  end

  def label(kind) = I18n.t("nexus_ccs.suggestions.kinds.#{kind}")

  # A title is searched for in titles; the other kinds are a filter over every record, as the header's Search collections menu does
  # (the any_assets marker keeps the default "With a digital asset" filter off: the suggestion was counted over every record)
  def query(field, value)
    field == "title_si" ? { q: value, search_field: "title" } : BrowseMenu.query(field, value)
  end
end
