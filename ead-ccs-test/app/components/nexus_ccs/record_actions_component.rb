# frozen_string_literal: true

module NexusCcs
  # What a visitor can do with a record, in one plain column beside the media (a strip that wraps below 1200px): the access notice
  # of a view-only record (it carries the request link), then Save, Add to list, Compare, Cite and Share and embed. The access chip
  # and the one primary action (Download image, for an open record) are in the slim toolbar under the image (DigitalAssetsComponent),
  # and a withheld record's notice is where its media would be. Nothing here is sticky.
  class RecordActionsComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    attr_reader :document

    def media = @media ||= RecordMedia.for(document, session: helpers.session)
    def tier = media.tier

    # The record has a digital asset, whether or not this visitor may see it now
    def assets? = media.images? || Array(document["digital_media_ssim"]).any?

    def notice? = assets? && tier == :view_only

    def compare? = media.shown? && media.images.any?

    def saved_records? = Rails.configuration.x.saved_records
  end
end
