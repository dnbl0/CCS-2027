# frozen_string_literal: true

module NexusCcs
  # The strip above the result cards for choosing records (CCS-40): how many are selected (a polite live region), Select all
  # on this page, Clear selection, and View selected. It is the form the cards' checkboxes belong to (the `form` attribute
  # points at FORM_ID), so it works without JavaScript: tick, then Update selection. selection_controller.js hides that
  # button and saves each tick as it is made, announcing the new count.
  # On the selection page (on_selection_page) the same form takes records out: untick them, then Remove unticked records.
  class SelectionBarComponent < ViewComponent::Base
    FORM_ID = "selection-form"

    # page_ids: the ids of the records on the page. return_to: where the form comes back to.
    def initialize(page_ids:, return_to:, on_selection_page: false)
      @page_ids = page_ids
      @return_to = return_to
      @on_selection_page = on_selection_page
    end

    attr_reader :page_ids, :return_to

    def render? = page_ids.any?

    def on_selection_page? = @on_selection_page

    def selection = @selection ||= Selection.new(helpers.session)

    def count_text = t("nexus_ccs.selection.status", count: selection.count)

    # The sentences JavaScript says when the count changes (the same wording as the server's), with %{count} to fill in
    def labels
      { zero: t("nexus_ccs.selection.status", count: 0), one: t("nexus_ccs.selection.status", count: 1),
        other: t("nexus_ccs.selection.status", count: "%{count}"), full: t("nexus_ccs.selection.full", count: Selection::MAX),
        view: t("nexus_ccs.selection.view_count", count: "%{count}"), error: t("nexus_ccs.selection.error") }
    end

    def data
      return {} if on_selection_page?

      { controller: "selection", action: "change@document->selection#changed", "selection-max-value": Selection::MAX,
        "selection-labels-value": labels.to_json, "selection-count-value": selection.count }
    end
  end
end
