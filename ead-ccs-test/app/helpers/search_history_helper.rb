# frozen_string_literal: true

# The Search History table gives a search's term and its filters their own columns, so the filters line up from row to
# row. Both cells link to the whole search (Blacklight's link_to_previous_search does the same for the one cell).
module SearchHistoryHelper
  # params: the search's saved parameters. Returns [term_link, filters_link]; filters_link is nil when there are none.
  def search_history_links(params)
    full = search_state.reset(params).to_hash
    filters = full.slice(*ZeroResults::FILTER_PARAMS)
    term = full.except(*ZeroResults::FILTER_PARAMS)

    [ search_history_link(term, full, empty_label: t("nexus_ccs.search_history.no_term")),
      (search_history_link(filters, full) if filters.values.any?(&:present?)) ]
  end

  private

  # The text of one part of a search (Blacklight's constraints), linked to the whole search
  def search_history_link(part, full, empty_label: nil)
    constraints = render(Blacklight::ConstraintsComponent.for_search_history(search_state: search_state.reset(part), classes: "constraints-container mb-0"))
    label = constraints.to_s.gsub(/<[^>]*>/, "").strip.empty? ? empty_label : constraints
    link_to(label, search_action_path(full))
  end
end
