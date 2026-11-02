# frozen_string_literal: true

# The Search History table gives a search's term and its filters their own columns, so the filters line up from row to
# row, and each row its actions as icon buttons with a tooltip.
module SearchHistoryHelper
  # Bootstrap Icons (16px grid), drawn in the current text colour
  ACTION_ICONS = {
    save: "M2 2a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v13.5a.5.5 0 0 1-.777.416L8 13.101l-5.223 2.815A.5.5 0 0 1 2 15.5zm2-1a1 1 0 0 0-1 1v12.566l4.723-2.482a.5.5 0 0 1 .554 0L13 14.566V2a1 1 0 0 0-1-1z",
    delete: "M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5m2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5m3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0zM14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4zM2.5 3h11V2h-11z",
    share: "M13.5 1a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3M11 2.5a2.5 2.5 0 1 1 .603 1.628l-6.718 3.12a2.5 2.5 0 0 1 0 1.504l6.718 3.12a2.5 2.5 0 1 1-.488.876l-6.718-3.12a2.5 2.5 0 1 1 0-3.256l6.718-3.12A2.5 2.5 0 0 1 11 2.5m-8.5 4a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3m11 5.5a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3"
  }.freeze

  # A decorative icon: the button's own text gives the name
  def history_action_icon(name)
    tag.svg(tag.path(d: ACTION_ICONS.fetch(name)), class: "history-action__icon", viewBox: "0 0 16 16", width: 16, height: 16,
            fill: "currentColor", aria: { hidden: true }, focusable: "false")
  end

  # An icon-only button's content: the icon, and its name as visually hidden text ("Save search: skull")
  def history_action_content(name, term_text)
    safe_join([ history_action_icon(name), tag.span(t("nexus_ccs.search_history.actions.#{name}_named", query: term_text), class: "visually-hidden", data: { clipboard_target: ("label" if name == :share) }.compact) ])
  end

  # params: the search's saved parameters. Returns [term_link, filter_pills]; filter_pills is nil when there are none.
  def search_history_cells(params)
    full = search_state.reset(params).to_hash
    filters = full.slice(*ZeroResults::FILTER_PARAMS)
    term = full.except(*ZeroResults::FILTER_PARAMS)

    [ search_history_term_link(term, full), (search_history_filters(filters) if filters.values.any?(&:present?)) ]
  end

  private

  # The search term (or "All records"), linked to the whole search
  def search_history_term_link(term, full)
    constraints = render(Blacklight::ConstraintsComponent.for_search_history(search_state: search_state.reset(term), classes: "constraints-container mb-0"))
    label = strip_tags(constraints).strip.empty? ? t("nexus_ccs.search_history.no_term") : constraints
    link_to(label, search_action_path(full))
  end

  # The filters as applied-filter pills (plain text: the term's link already opens the search)
  def search_history_filters(filters)
    render(Blacklight::ConstraintsComponent.new(
      search_state: search_state.reset(filters), tag: :span, render_headers: false, id: nil, classes: "constraints-container",
      query_constraint_component: NexusCcs::HistoryFilterPillComponent,
      facet_constraint_component_options: { layout: NexusCcs::HistoryFilterPillComponent },
      start_over_component: nil
    ))
  end
end
