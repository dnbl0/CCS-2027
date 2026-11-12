# frozen_string_literal: true

module NexusCcs
  # What a record with no digital asset says where its media would be: one plain sentence, no box and no icon, and a link to ask
  # the collection team only where the collection takes questions (CollectionContact: an email address or the access request
  # form). The wording is PLACEHOLDER wording (config/locales/record_page.en.yml).
  class NoImageComponent < ViewComponent::Base
    def initialize(document:, url:)
      @document = document
      @url = url
    end

    # The first letters of the collection's first two words, as the home page's collection tiles have them
    def monogram = Array(@document["collection_ssim"]).first.to_s.split.first(2).map { |word| word[0].to_s.upcase }.join.presence || "·"

    def contact = @contact ||= CollectionContact.for(Array(@document["collection_ssim"]).first)

    def href
      return unless contact

      contact.email? ? contact.mailto(document: @document, url: @url) : contact.url
    end

    def new_tab? = contact&.form?
  end
end
