# frozen_string_literal: true

module NexusCcs
  # What RecordDocumentComponent needs for de-bias notices (DebiasTerms): the finds in the text its details list displays, and a
  # field value with its finds marked. Only the displayed rows are scanned, so the notice cannot show text the page does not.
  # With an empty term list `flagged` returns the value untouched, so the page is byte for byte what it was.
  module RecordDebias
    def debias_matches
      @debias_matches ||= DebiasTerms.scan(rows.reject { |row| row.copy || link_to_value?(row) }.to_h { |row| [ row.field, row.values ] })
    end

    def debias_labels = rows.to_h { |row| [ row.field, row.label ] }

    def flagged(row, value, index)
      @debias_by_value ||= debias_matches.group_by { |match| [ match.field, match.value_index ] }
      found = @debias_by_value[[ row.field, index ]]
      found ? DebiasTerms::Highlight.call(value, found, label: t("nexus_ccs.debias.flagged_label")) : value
    end
  end
end
