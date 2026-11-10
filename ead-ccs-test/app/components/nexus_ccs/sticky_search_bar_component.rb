# frozen_string_literal: true

module NexusCcs
  # The search bar of the sticky strip: the same bar as the banner's and the home hero's (query, scope menu, search
  # button, "Advanced search" link), built from the same Blacklight SearchBarComponent. It shares a page with that
  # bar, so its field ids are namespaced ("sticky_q", "sticky_search_field"), the search button and the suggestion list
  # have their own ids; the field names stay q and search_field, so it submits exactly like the other. Suggestions as
  # you type are Blacklight's own (the same suggest endpoint as the banner's bar).
  class StickySearchBarComponent < SearchBannerComponent
    def search_bar_component_class = NexusCcs::SuggestingSearchBarComponent

    def search_bar_component
      search_bar_component_class.new(
        url: helpers.search_catalog_path,
        advanced_search_url: advanced_search_url,
        params: helpers.search_state.params_for_search.except(:qt, :view),
        autocomplete_path: suggest_index_catalog_path,
        classes: %w[search-query-form search-banner__form],
        form_options: { namespace: "sticky" }
      ).tap do |bar|
        bar.with_search_button { helpers.render(Blacklight::SearchButtonComponent.new(id: "sticky-search-submit", text: I18n.t("blacklight.search.form.submit"))) }
      end
    end
  end
end
