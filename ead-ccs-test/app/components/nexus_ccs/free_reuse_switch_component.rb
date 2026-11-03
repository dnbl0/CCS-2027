# frozen_string_literal: true

module NexusCcs
  # The "Open licence (public domain)" switch in the results sidebar (FreeReuse). It is a small GET form: a button with role
  # "switch" that sends the search with the filter added or taken off, so it works without JavaScript, answers to Space and
  # Enter, and tells a screen reader its state. The filter is the facet field `free_reuse`, so it also appears as a pill.
  # Registered as the facet's `component` (CatalogConfig::Facets).
  class FreeReuseSwitchComponent < Blacklight::Component
    def initialize(facet_field:, layout: nil)
      @facet_field = facet_field
    end

    # Shown whatever the count: a switch that vanishes when it matches nothing hides that it exists
    def render? = true

    def label = I18n.t("nexus_ccs.free_reuse.label")

    def filter = helpers.search_state.filter(@facet_field.facet_field)

    def on? = filter.values.include?(FreeReuse::VALUE)

    # The search as it will be once the switch is pressed
    def toggled_params
      state = on? ? filter.remove(FreeReuse::VALUE) : filter.add(FreeReuse::VALUE)
      state.params_for_search.except(:page, :action, :controller)
    end

    # Records matching the filter within the current search, or nil when Solr was not asked
    def hits
      @facet_field.paginator&.items&.find { |item| item.value.to_s == FreeReuse::VALUE }&.hits
    end

    def count_text = hits && helpers.number_with_delimiter(hits)

    def description_id = "free-reuse-description"
  end
end
