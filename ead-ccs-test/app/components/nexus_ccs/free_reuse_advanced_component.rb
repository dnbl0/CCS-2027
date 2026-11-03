# frozen_string_literal: true

module NexusCcs
  # The same switch on the Advanced search form: a checkbox (with the switch role) sent with the Search button as
  # f_inclusive[free_reuse][]. When the search already has the filter (a pill above the form), the box is shown on and the
  # note says how to take it off, because the form carries the existing filters along as they are.
  class FreeReuseAdvancedComponent < Blacklight::Component
    def initialize(facet_field:, layout: nil)
      @facet_field = facet_field
    end

    def render? = true

    def label = I18n.t("nexus_ccs.free_reuse.label")

    def input_id = "advanced-free-reuse"

    def input_name = "f_inclusive[#{FreeReuse::FIELD}][]"

    def selected_values = helpers.search_state.filter(@facet_field.facet_field).values

    def checked? = selected_values.include?(FreeReuse::VALUE)

    # On because of a filter already applied to the search (f), not chosen on this form
    def carried? = Array(helpers.search_state.params.dig(:f, FreeReuse::FIELD)).include?(FreeReuse::VALUE)
  end
end
