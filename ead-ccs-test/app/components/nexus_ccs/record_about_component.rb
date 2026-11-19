# frozen_string_literal: true

module NexusCcs
  # "About this record", the last band of a record page (approved split layout): three rows, each a heading beside its text. Help us
  # improve this record (the correction link goes where contacting the team does: the collection's email address or its form, or the
  # Help page's Contact us section, so it adds no new page); Content notice (the advisory every record carries); Use this record (the
  # persistent link with a Copy button, the details as a spreadsheet when the record may be downloaded, and the IIIF manifest when the
  # visitor may see its images; then View full record, the record in its source catalogue behind the leaving-site dialog). Wording marked PLACEHOLDER in config/locales/record_page.en.yml.
  class RecordAboutComponent < ViewComponent::Base
    def initialize(document:, url:)
      @document = document
      @url = url
    end

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
