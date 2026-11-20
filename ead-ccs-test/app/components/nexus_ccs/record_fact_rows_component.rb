# frozen_string_literal: true

module NexusCcs
  # A list of record details (label above value), drawn by RecordDocumentComponent for its Key facts and for each group of the full
  # record. Each row is one of the record's display fields (RecordDocumentComponent::Row): names of things as outlined terms that
  # open their search or browse page (joined as the data model sheet says, e.g. a classification hyphenated), Source URL as the
  # View full record button, anything else as text. The record component answers for links and de-bias marks (record:).
  class RecordFactRowsComponent < ViewComponent::Base
    def initialize(rows:, record:, id_row: false)
      @rows = rows
      @record = record
      @id_row = id_row
    end

    attr_reader :rows, :record

    def id_row? = @id_row

    def render? = rows.any? || id_row?

    # The mark drawn between a row's terms: a hyphen means something (Classification's primary - secondary), a comma only separates
    # what the tags already show apart, so it is not drawn
    def joiner(row) = row.join&.strip.presence&.then { |mark| mark unless mark == "," }

    # A long text (an inscription, a note) fades out after a few lines above Read more, as the description does
    LONG_TEXT = 280

    def long?(row) = !row.join && row.values.sum(&:length) > LONG_TEXT

    def text_id(row) = "record-text-#{row.field.to_s.parameterize}"

    # The values of a text row, each on its own line, or joined into one line where the sheet says so
    def text_values(row)
      flagged = row.values.each_with_index.map { |value, index| record.flagged(row, value, index) }
      row.join ? [ safe_join(flagged, row.join) ] : flagged
    end
  end
end
