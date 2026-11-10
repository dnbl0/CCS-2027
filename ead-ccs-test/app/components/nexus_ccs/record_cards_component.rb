# frozen_string_literal: true

module NexusCcs
  # A section of the record page that lists records as cards (RecordCardComponent): a Fraunces h2 (an h3 when nested in More like this), an optional one-line
  # description, and at most four cards in a grid (4 columns from 1024px, 2 from 600px, 1 below). Renders nothing without records.
  class RecordCardsComponent < ViewComponent::Base
    MAX = 4

    def initialize(id:, heading:, documents:, description: nil, compact: false, heading_id: nil, nested: false)
      @id = id
      @heading = heading
      @documents = documents
      @description = description
      @compact = compact
      @heading_id = heading_id || "#{id}-heading"
    @nested = nested
    end

    attr_reader :id, :heading, :description, :heading_id

    def documents = @documents.first(MAX)

    def render? = @documents.any?

    def compact? = @compact

    # nested: a sub-section of More like this (an h3 inside its h2), not a section of the page
    def nested? = @nested

    def heading_tag = nested? ? :h3 : :h2

    def classes = [ "object-cards", ("object-cards--compact" if compact?), ("object-cards--nested" if nested?) ].compact.join(" ")
  end
end
