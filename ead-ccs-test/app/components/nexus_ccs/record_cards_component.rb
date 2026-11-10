# frozen_string_literal: true

module NexusCcs
  # A section of the record page that lists records as cards (RecordCardComponent): a Fraunces h2, an optional one-line
  # description, and at most four cards in a grid (4 columns from 1024px, 2 from 600px, 1 below). Renders nothing without records.
  class RecordCardsComponent < ViewComponent::Base
    MAX = 4

    def initialize(id:, heading:, documents:, description: nil, compact: false, heading_id: nil)
      @id = id
      @heading = heading
      @documents = documents
      @description = description
      @compact = compact
      @heading_id = heading_id || "#{id}-heading"
    end

    attr_reader :id, :heading, :description, :heading_id

    def documents = @documents.first(MAX)

    def render? = @documents.any?

    def compact? = @compact

    def classes = [ "object-cards", ("object-cards--compact" if compact?) ].compact.join(" ")
  end
end
