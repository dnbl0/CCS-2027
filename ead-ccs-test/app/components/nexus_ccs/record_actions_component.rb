# frozen_string_literal: true

module NexusCcs
  # What a visitor can do with a record, in one row under its title in the record's column (approved split layout): Save, Add to
  # list, Share and Cite, with Compare under them when the record has images to compare. What they may do with the image (view,
  # download, request) is the Use and access panel under it (RecordDocumentComponent); Download is a round tool under the image
  # (DigitalAssetsComponent), and a withheld record's notice is where its media would be.
  class RecordActionsComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    attr_reader :document

    def media = @media ||= RecordMedia.for(document, session: helpers.session)
    def tier = media.tier

    def compare? = media.shown? && media.images.any?

    def saved_records? = Rails.configuration.x.saved_records
  end
end
