# frozen_string_literal: true

# What a results request (/catalog) gets before it is searched. The rules, in order:
#
#   1. Nothing asked (no search, filter or sort): the home page, which has the hero search.
#   2. The Advanced search form sent with nothing in it: the form again, with a notification, instead of every record.
#   3. No Digital asset choice made: the same search with "With a digital asset" applied (docs/adr/0004). Taking that
#      filter off leaves the `any_assets` marker (DigitalAssetFilterField), which stops it coming back. Advanced
#      searches are left alone: the visitor sets Digital asset on the form.
#
# Rules 1 and 3 are for the catalog itself; controllers built on it (BookmarksController) get rule 2 only.
#
# SearchDefaults.decide returns nil (search as asked), or one of:
#   [ :home ]
#   [ :advanced_search_again, op ]   op: the form's all/any choice to keep, or nil
#   [ :search, query ]               query: the request's query with the default filter added
module SearchDefaults
  DIGITAL_ASSET_FIELD = "has_digital_asset"

  # query: the request's query parameters (string keys, as Rack parses them)
  def self.decide(query, html:, get:, catalog:)
    return unless html
    return [ :home ] if catalog && query.empty?
    return [ :advanced_search_again, query["op"].presence ] if empty_advanced_search?(query)
    return [ :search, with_digital_asset_filter(query) ] if catalog && get && wants_default_filter?(query)

    nil
  end

  def self.empty_advanced_search?(query)
    return false unless query["clause"].present? && query["q"].blank?
    return false if query["f"].present? || query["f_inclusive"].present? || years_given?(query)

    AdvancedRules.rules(query["clause"]).none?(&:active?) # a term, or a "has a value" / "is empty" rule
  end

  # The form sends every year filter's From and To, blank or not: only a year filled in counts
  def self.years_given?(query)
    ranges = query["range"].is_a?(Hash) ? query["range"].values : Array(query["range"])
    ranges.any? { |range| range.is_a?(Hash) ? range.values.any?(&:present?) : range.present? }
  end

  def self.wants_default_filter?(query)
    return false if query.empty? || query[DigitalAssetFilterField::ANY_ASSETS_PARAM].present? || query["clause"].present?

    filters(query)[DIGITAL_ASSET_FIELD].blank?
  end

  def self.with_digital_asset_filter(query)
    query.merge("f" => filters(query).merge(DIGITAL_ASSET_FIELD => [ "with" ]))
  end

  # A hand-edited f that is not a list of filters is left for the search itself to refuse
  def self.filters(query) = query["f"].is_a?(Hash) ? query["f"] : {}

  private_class_method :empty_advanced_search?, :years_given?, :wants_default_filter?, :with_digital_asset_filter, :filters
end
