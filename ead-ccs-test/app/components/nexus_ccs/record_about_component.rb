# frozen_string_literal: true

module NexusCcs
  # "About this record": the persistent link with its Copy link button, who to contact about the record, and a link to suggest a
  # correction, in one block at the end of the record's details. The correction link goes to the same place as contacting the
  # team (the collection's email address or its form; the Help page's Contact us section for any other), so it adds no new page.
  # Its wording is PLACEHOLDER wording (config/locales/record_page.en.yml).
  class RecordAboutComponent < ViewComponent::Base
    # viewer: the viewer layout's accordion, without the persistent link (that layout has it in its own card)
    def initialize(document:, url:, viewer: false)
      @document = document
      @url = url
      @viewer = viewer
    end

    attr_reader :document, :url

    def viewer? = @viewer

    def contact = @contact ||= CollectionContact.for(Array(document["collection_ssim"]).first)

    def correction_href
      return "/help#contact-us" unless contact

      contact.email? ? contact.mailto(document: document, url: url).sub(/subject=[^&]*/, "subject=#{ERB::Util.url_encode("Correction: #{CollectionIdentifier.uom_id(document.id)}")}") : contact.url
    end

    def correction_new_tab? = contact&.form?
  end
end
