# frozen_string_literal: true

module NexusCcs
  # "About this record", at the foot of the record card (showcase layout): what the record is and that it may be corrected, the content
  # notice every record carries, Suggest a correction (it goes where contacting the team does: the collection's email address or its
  # form, or the Help page's Contact us section), then the record's permanent address with Copy link, Print this page, and the
  # details as a spreadsheet (when the record may be downloaded) and the IIIF manifest (when the visitor may see its images). The
  # record in its source catalogue is the Source URL row of Object details. Wording marked PLACEHOLDER in config/locales/record_page.en.yml.
  class RecordAboutComponent < ViewComponent::Base
    # heading: false inside a folding section whose summary is the heading
    def initialize(document:, url:, heading: true)
      @document = document
      @url = url
      @heading = heading
    end

    def heading? = @heading

    attr_reader :document, :url

    def contact = @contact ||= CollectionContact.for(Array(document["collection_ssim"]).first)

    def correction_href
      return "/help#contact-us" unless contact

      contact.email? ? contact.mailto(document: document, url: url).sub(/subject=[^&]*/, "subject=#{ERB::Util.url_encode("Correction: #{CollectionIdentifier.uom_id(document.id)}")}") : contact.url
    end

    def correction_new_tab? = contact&.form?

    def advisory = DigitalAssetsComponent::ADVISORY

    # The details as a spreadsheet (CCS-163), offered when the record may be downloaded
    def export_path = (helpers.metadata_export_path(document.id) if AccessPolicy.download?(document))

    # The IIIF manifest (CCS-57), offered when it would answer: the visitor may see the record's images
    def manifest_path
      media = RecordMedia.for(document, session: helpers.session)
      helpers.manifest_path(document.id) if media.shown? && media.images.any?
    end
  end
end
