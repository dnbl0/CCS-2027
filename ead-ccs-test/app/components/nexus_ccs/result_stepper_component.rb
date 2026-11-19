# frozen_string_literal: true

module NexusCcs
  # "Result 3 of 120" with round previous and next buttons, at the top of the record's column (approved split layout): Blacklight's
  # search-context pagination (ServerItemPaginationComponent: the same session tracking, so the links carry the counter), drawn
  # as the design draws it. Nothing when the visitor did not arrive from a search. An end of the list keeps its button's place,
  # disabled and named ("Previous result: none"), so the other does not move.
  class ResultStepperComponent < Blacklight::SearchContext::ServerItemPaginationComponent
    Step = Struct.new(:context_key, :offset, :rel, :glyph)
    STEPS = { previous: Step.new(:prev, -1, "prev", :chevron_left), next: Step.new(:next, 1, "next", :chevron_right) }.freeze

    def position = t("nexus_ccs.record_page.split.stepper.position", current: number_with_delimiter(count), total: number_with_delimiter(total))

    def step_link(direction)
      step = STEPS.fetch(direction)
      target = @search_context[step.context_key]
      label = t("nexus_ccs.record_page.split.stepper.#{direction}")
      icon = Glyphs.svg(step.glyph, size: 18)
      unless target
        return tag.span(icon + tag.span(t("nexus_ccs.record_page.split.stepper.none", label: label), class: "visually-hidden"),
                        class: "result-stepper__step", "aria-disabled": "true")
      end

      options = session_tracking_params(target, count + step.offset, per_page: per_page, search_id: search_id)
      link_to icon + tag.span(label, class: "visually-hidden"), url_for_document(target), **options, class: "result-stepper__step", rel: step.rel
    end
  end
end
