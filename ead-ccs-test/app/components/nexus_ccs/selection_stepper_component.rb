# frozen_string_literal: true

module NexusCcs
  # On a record that is in the visitor's selection (CCS-40): where it is in the selection, and links to the previous and next
  # selected record and to the whole selection, so the selected records can be read in sequence. Nothing for any other record.
  class SelectionStepperComponent < ViewComponent::Base
    def initialize(document_id:)
      @document_id = document_id.to_s
    end

    def render? = position.present?

    def selection = @selection ||= Selection.new(helpers.session)

    def position = @position ||= selection.position(@document_id)

    def previous_path
      id = selection.previous_id(@document_id)
      id && helpers.solr_document_path(id)
    end

    def next_path
      id = selection.next_id(@document_id)
      id && helpers.solr_document_path(id)
    end
  end
end
