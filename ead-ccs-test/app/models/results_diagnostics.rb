# frozen_string_literal: true

# "Why am I seeing these results?" (CCS-43): what a results page can tell a visitor about a search that found nothing or only a
# few records, in plain language and without Solr's vocabulary. The page's words come from the search the visitor made (its
# parameters) and from the facts SearchService adds to the response: how many records the search finds without each filter
# (Removal#total), asked only when the search finds none or few. The panel itself is NexusCcs::SearchDiagnosticsComponent.
module ResultsDiagnostics
  # "Few" results: the panel is offered below this many, and the extra counts are asked for
  FEW_RESULTS = 10
  # A search with more filters than this is not counted filter by filter (each count is a request to the index)
  MAX_REMOVALS = 8

  FILTER_KEYS = %w[f f_inclusive range].freeze

  # One filter the visitor could take off. params: the search without it (string keys, as ZeroResults.without_filters).
  # total: how many records that search finds, nil until counted.
  Removal = Data.define(:field, :label, :params, :total) do
    def with_total(count) = with(total: count)
  end

  # Added to a response SearchService has counted
  module Response
    attr_accessor :filter_removals
  end

  # Whether the panel is offered: a search or filters were given, and there are fewer than FEW_RESULTS records
  def self.applies?(total:, params:)
    total < FEW_RESULTS && (params["q"].present? || params["clause"].present? || FILTER_KEYS.any? { |key| params[key].present? })
  end

  # Each filter value or year range, as something that can be taken off, in the order the page lists them. Taking the
  # default "With a digital asset" off leaves the any_assets marker so it does not come back (DigitalAssetFilterField).
  # params: the search state's parameters (string keys); facets: blacklight_config.facet_fields
  def self.removals(params, facets)
    params = params.to_h.deep_stringify_keys.except("page", "controller", "action")
    list = %w[f f_inclusive].flat_map do |key|
      hash_of(params[key]).flat_map do |field, values|
        Array(values).map { |value| Removal.new(field, value_label(field, value, facets), without_value(params, key, field, value), nil) }
      end
    end
    list += hash_of(params["range"]).filter_map do |field, range|
      next unless range.is_a?(Hash) && range.values.any?(&:present?)

      Removal.new(field, range_label(field, range, facets), params.merge("range" => hash_of(params["range"]).except(field)).compact_blank, nil)
    end
    list
  end

  # "Collection: Grainger Museum"; the Digital asset choices are named by their own labels ("With a digital asset")
  def self.value_label(field, value, facets)
    config = facets[field]
    named = config&.query&.dig(value.to_s, :label)
    named || "#{field_label(field, facets)}: #{value}"
  end

  def self.range_label(field, range, facets)
    from = range["begin"].presence
    to = range["end"].presence
    span = if from && to then "#{from}–#{to}"
    elsif from then I18n.t("nexus_ccs.diagnostics.from_year", year: from)
    else I18n.t("nexus_ccs.diagnostics.to_year", year: to)
    end
    "#{field_label(field, facets)}: #{span}"
  end

  def self.field_label(field, facets)
    label = facets[field]&.label
    label.is_a?(String) && label.present? ? label : field.to_s.humanize
  end

  def self.without_value(params, key, field, value)
    remaining = Array(hash_of(params[key])[field]) - [ value ]
    filters = hash_of(params[key]).merge(field => remaining).reject { |_field, values| values.blank? }
    result = params.merge(key => filters).compact_blank
    return result unless field == SearchDefaults::DIGITAL_ASSET_FIELD && remaining.empty?

    result.merge(DigitalAssetFilterField::ANY_ASSETS_PARAM => "1") # taking the default off, as its own pill's link does
  end

  # The quoted phrases of a plain search ("human skull") and the words outside them
  def self.phrases(query) = query.to_s.scan(/"([^"]+)"/).flatten.map(&:strip).reject(&:empty?)

  def self.words(query)
    query.to_s.gsub(QuerySyntax::PHRASE, " ").split.reject { |word| word.match?(/\A(?:AND|OR|NOT)\z/) }
  end

  # SearchBuilder::KEYWORD_MM ("4<-1 7<-2") in words: how many of a plain search's words a record may lack.
  # Returns [ [ from_words, to_words_or_nil, may_lack ], ... ] in the order of the words: [ [1, 4, 0], [5, 7, 1], [8, nil, 2] ]
  def self.words_needed(mm = SearchBuilder::KEYWORD_MM)
    steps = mm.split.filter_map do |step|
      limit, lack = step.match(/\A(\d+)<-(\d+)\z/)&.captures
      [ limit.to_i, lack.to_i ] if limit
    end
    rows = []
    start = 1
    lack = 0
    steps.each do |limit, may_lack|
      rows << [ start, limit, lack ]
      start = limit + 1
      lack = may_lack
    end
    rows << [ start, nil, lack ]
  end

  def self.hash_of(value) = value.is_a?(Hash) ? value : {}
  private_class_method :hash_of
end
