# frozen_string_literal: true

module NexusCcs
  # Dark banner under the site header: page title, result summary and the search form.
  # Takes the place of Blacklight's light search band (Blacklight::SearchNavbarComponent).
  class SearchBannerComponent < Blacklight::SearchNavbarComponent
    TITLE = "Search the collections"
    DESCRIPTION = "Explore artworks, objects, manuscripts, photographs and recordings held across the University of Melbourne's cultural collections."

    # The gem's default classes size the form with grid columns; the banner sizes it in CSS.
    def search_bar_component
      search_bar_component_class.new(
        url: helpers.search_catalog_path,
        advanced_search_url: advanced_search_url,
        params: helpers.search_state.params_for_search.except(:qt, :view), # a new search opens in the default view
        autocomplete_path: suggest_index_catalog_path,
        classes: %w[search-query-form search-banner__form]
      )
    end

    # The "Advanced search" link goes to Blacklight's own, unmodified advanced search page. The current query
    # becomes the first row's "all fields" clause, so opening it does not look like starting over.
    def advanced_search_url
      state = helpers.search_state.params_for_search.except(:qt, :page, :action, :controller).to_h.with_indifferent_access
      if state[:clause].blank? && state[:q].present?
        state[:clause] = { "0" => { field: "all_fields", query: state.delete(:q) } }
      end
      helpers.advanced_search_catalog_path(state)
    end

    def controllers
      { controller: "select-dropdown", "select-dropdown-selector-value": "select.search-field" }
    end

    def summary
      total = helpers.instance_variable_get(:@response)&.total
      return if total.nil? || !helpers.has_search_parameters?

      query = helpers.params[:q].presence
      text = "#{helpers.number_with_delimiter(total)} #{"result".pluralize(total)}"
      query ? safe_join([ text, " for “#{query}”" ]) : text
    end
  end
end
