# frozen_string_literal: true

module NexusCcs
  # "Result 3 of 120" with round previous and next buttons, at the top of the record's column (approved split layout): Blacklight's
  # search-context pagination (ServerItemPaginationComponent: the same session tracking, so the links carry the counter), drawn
  # as the design draws it. Nothing when the visitor did not arrive from a search. An end of the list keeps its button's place,
  # disabled, so the other does not move.
  class ResultStepperComponent < Blacklight::SearchContext::ServerItemPaginationComponent
    def position = t("nexus_ccs.record_page.split.stepper.position", current: number_with_delimiter(count), total: number_with_delimiter(total))

    def step_link(direction)
      target = @search_context[direction == :previous ? :prev : :next]
      label = t("nexus_ccs.record_page.split.stepper.#{direction}")
      return tag.span(icon(direction), class: "result-stepper__step", "aria-disabled": "true", title: label) unless target

      offset = direction == :previous ? -1 : 1
      options = session_tracking_params(target, count + offset, per_page: per_page, search_id: search_id)
      link_to icon(direction) + tag.span(label, class: "visually-hidden"), url_for_document(target),
              **options, class: "result-stepper__step", rel: direction == :previous ? "prev" : "next"
    end

    private

    def icon(direction)
      path = direction == :previous ? "m15 18-6-6 6-6" : "m9 18 6-6-6-6"
      tag.svg(tag.path(d: path), width: 18, height: 18, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
                                 "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": "true", focusable: "false")
    end
  end
end
