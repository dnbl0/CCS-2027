# frozen_string_literal: true

module NexusCcs
  # The search results sidebar. From 992px it is a plain left column; below that it is an off-canvas
  # drawer opened by FilterToggleComponent (controllers/filter_drawer_controller.js). Registered as
  # config.index.sidebar_component; the facet groups are Blacklight's own.
  class FilterSidebarComponent < Blacklight::Search::SidebarComponent
    def applied_count
      helpers.applied_filter_count
    end

    # What a screen reader is told once a filter has changed the results: "7,719 results, 1 filter applied".
    def status_message
      total = response.total
      [ t("nexus_ccs.facets.status.results", count: total).sub(total.to_s, helpers.number_with_delimiter(total)),
        t("nexus_ccs.facets.status.filters", count: applied_count) ].join(", ")
    end

    # The same search (words, search field, sort, view) with every filter taken off.
    def clear_filters_path
      helpers.search_action_path(helpers.search_state.params_for_search.except(:f, :f_inclusive, :range, :page))
    end
  end
end
