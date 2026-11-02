# frozen_string_literal: true

module NexusCcs
  # A filter of a past search in the Search History table, drawn as the results page draws an applied filter (the
  # "applied-filter" pill, styled in unimelb.css), without its remove button: the table's rows are not editable here.
  # The filter's name stays in the markup, visually hidden, so a screen reader hears "Digital asset: With a digital asset".
  class HistoryFilterPillComponent < Blacklight::ConstraintLayoutComponent
    def call
      name = tag.span(t("blacklight.search.filters.label", label: @label), class: "filter-name") if @label.present?
      value = tag.span(@value, class: "filter-value")

      tag.span(class: "btn-group applied-filter constraint #{@classes}") do
        tag.span(safe_join([ name, value ].compact), class: "constraint-value btn btn-outline-secondary")
      end
    end
  end
end
