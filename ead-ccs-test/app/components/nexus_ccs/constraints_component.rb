# frozen_string_literal: true

module NexusCcs
  # The line above the results: "385 results for" and the search and filters as removable pills. It sits in the
  # results toolbar (catalog/_sort_and_per_page), so Blacklight's own copy in the page header, which
  # builds this component without `inline:`, renders nothing. The "Start over" button is not used: pills
  # remove one thing each, and the sidebar has "Clear all".
  class ConstraintsComponent < Blacklight::ConstraintsComponent
    def initialize(search_state:, inline: false, **)
      super(search_state: search_state, start_over_component: nil, classes: "constraints-container", **)
      @inline = inline
    end

    def render?
      @inline
    end

    def total
      helpers.instance_variable_get(:@response)&.total.to_i
    end

    def heading
      count = helpers.number_with_delimiter(total)
      text = "#{count} #{"result".pluralize(total)}"
      @search_state.has_constraints? ? "#{text} for" : text
    end

    private

    # Blacklight shows an "any of" filter (f_inclusive: two or more values chosen in one multi-select filter) as one pill,
    # "A OR B", whose ✕ takes them all off. For a filter whose values are alternatives (InclusiveFilterField) each value is a
    # pill of its own, removed on its own: the remove link comes from InclusiveFilterField#remove, which keeps the other values.
    # Any other "any of" filter keeps Blacklight's single pill, as its filter field cannot take off one value of the group.
    def constraint_presenters
      return to_enum(:constraint_presenters) unless block_given?

      @search_state.filters.each do |facet|
        facet_field_presenter = helpers.facet_field_presenter(facet.config, {})
        facet.each_value do |value|
          next if value.blank?

          if !value.is_a?(Array)
            yield facet_constraint_presenter(facet_field_presenter, facet.config, value)
          elsif facet.config.filter_class == InclusiveFilterField
            value.compact_blank.each { |one| yield facet_constraint_presenter(facet_field_presenter, facet.config, one) }
          elsif value.any?(&:present?)
            yield inclusive_facet_constraint_presenter(facet_field_presenter, facet.config, value, facet.key)
          end
        end
      end
    end
  end
end
