# frozen_string_literal: true

# The empty results page. A search can find nothing only because of its filters, most often the default "With a digital
# asset" one (SearchDefaults): "skull" matches hundreds of records, none with a digital asset. The page then says how many
# results the filters hide (SearchService counts them) and its links keep the search, taking off only the filters.
module ZeroResults
  FILTER_PARAMS = %w[f f_inclusive range].freeze

  # params: the search state's parameters (string keys)
  def self.filtered?(params) = FILTER_PARAMS.any? { |key| params[key].present? }

  # The same search with no filters. The any_assets marker stops the default filter coming back (SearchDefaults).
  def self.without_filters(params)
    params.to_h.stringify_keys.except(*FILTER_PARAMS, "page", "controller", "action")
          .merge(DigitalAssetFilterField::ANY_ASSETS_PARAM => "1")
  end

  # The default filter is the only one applied, so the page can name it
  def self.only_default_filter?(params)
    return false if params["f_inclusive"].present? || params["range"].present?

    params["f"].is_a?(Hash) && params["f"].to_h.stringify_keys == { SearchDefaults::DIGITAL_ASSET_FIELD => [ "with" ] }
  end

  # Related categories an empty page offers (CCS discovery aids): the commonest collection, object type and creator among the
  # records the same search finds without its filters (from the facets of the one request that counts them, SearchService), or,
  # when the words find nothing at all, the categories whose names contain the longest word (CategorisedSuggestions).
  RELATED_FIELDS = { "collection_ssim" => :collection, "object_type_ssim" => :object_type, "creator_ssim" => :creator }.freeze
  RELATED_MAX = 3
  MIN_WORD = 3

  Category = Data.define(:value, :kind, :query)

  # facet_fields: Solr's facet_counts.facet_fields; params: the search's parameters (string keys). The same search, without its
  # filters, with the category's one filter
  def self.related_from_facets(facet_fields, params)
    return [] unless facet_fields.is_a?(Hash)

    base = without_filters(params)
    RELATED_FIELDS.filter_map do |field, kind|
      value = Array(facet_fields[field]).first.presence or next
      Category.new(value: value.to_s, kind: I18n.t("nexus_ccs.suggestions.kinds.#{kind}"), query: base.merge("f" => { field => [ value.to_s ] }))
    end.first(RELATED_MAX)
  end

  # query: the visitor's words. One request (finder) for the longest word; titles are left out (they are records, not categories)
  def self.related_from_words(query, finder: CategorisedSuggestions.method(:for))
    word = query.to_s.gsub(QuerySyntax::PHRASE, " ").scan(/[[:alnum:]][[:alnum:]'-]*/).max_by(&:length)
    return [] if word.nil? || word.length < MIN_WORD

    title = I18n.t("nexus_ccs.suggestions.kinds.title")
    finder.call(word.downcase).reject { |item| item.kind == title }.first(RELATED_MAX)
          .map { |item| Category.new(value: item.value, kind: item.kind, query: item.query) }
  end

  # Added to an empty response: how many results the same search finds without its filters (a filtered search), and related
  # categories to try
  module Response
    attr_accessor :unfiltered_total, :related_categories
  end
end
