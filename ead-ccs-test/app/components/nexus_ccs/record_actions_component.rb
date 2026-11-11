# frozen_string_literal: true

module NexusCcs
  # The access card of a record page, after the summary card of Apple's product pages: a large line saying what the visitor can do with
  # the record's media, ONE full-width primary button where there is something to do (Download image for an open record, Request access
  # for a withheld one; none for a view-only record, which gets its plain reason and a text link to ask instead), then the quiet text
  # actions as 44px rows: Save, Add to list, Compare, Cite this record and Share and embed. The Collection ID with Copy (CCS-22) ends
  # it. Compare, Cite and Share sit in a "More actions" disclosure that is closed on a phone and open from 768px
  # (controllers/record_sections_controller.js). Follows AccessPolicy; nothing of a withheld asset is in the markup.
  class RecordActionsComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
    end

    attr_reader :document

    def media = @media ||= RecordMedia.for(document, session: helpers.session)
    def tier = media.tier

    # The record has a digital asset, whether or not this visitor may see it now
    def assets? = media.images? || Array(document["digital_media_ssim"]).any?

    def compare? = media.shown? && media.images.any?

    def saved_records? = Rails.configuration.x.saved_records

    # What the large line says: nil for a record with no media
    def headline = (t("nexus_ccs.record_page.access_card.#{tier}.headline") if assets?)

    def download_href = (media.images.first&.url if tier == :open)
    def download? = assets? && download_href.present?

    # A withheld record's one button asks for access; a view-only record's reason carries a text link instead
    def request? = assets? && tier == :request
    def view_only? = assets? && tier == :view_only
    def request_path = AccessPolicy.request_path(document)

    def title = Array(document["title_tsim"]).first.presence || "Record"

    # "Grainger Museum Collection, accession number 00.0001, UoM ID emu-umc-400001"
    def identifier = CollectionIdentifier.new(document).to_s
  end
end
