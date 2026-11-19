# frozen_string_literal: true

module NexusCcs
  # What a visitor can do with a record, in one row under its title in the record's column (approved split layout): the access
  # notice of a view-only record (it carries the request link), then Save, Add to list, Share and Cite, with Compare under them
  # when the record has images to compare. Download is a round tool under the image (DigitalAssetsComponent), and a withheld
  # record's notice is where its media would be.
  class RecordActionsComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    attr_reader :document

    def media = @media ||= RecordMedia.for(document, session: helpers.session)
    def tier = media.tier

    # The record has a digital asset, whether or not this visitor may see it now
    def assets? = RecordMedia.assets?(document)

    def notice? = assets? && tier == :view_only

    def compare? = media.shown? && media.images.any?

    def saved_records? = Rails.configuration.x.saved_records
  end
end
