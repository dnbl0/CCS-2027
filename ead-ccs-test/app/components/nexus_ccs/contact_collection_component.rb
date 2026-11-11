# frozen_string_literal: true

module NexusCcs
  # "Contact the collection team" on a record page (CCS-47): how to ask the record's collection about it. Collections with
  # an email address get a mailto link that starts a message with the record's ID as the subject and its title, link and
  # accession number in the body, so the team knows which record it is about (the Jira story: the team must know where a
  # request came from). Museums & Collections' collections get the Smartsheet form, which opens in a new tab. A collection
  # not in CollectionContact points to the Help page. Contact us is for questions; "Request access" (AccessPolicy,
  # AccessRequestsController) is for viewing or downloading a record's digital assets, so it is offered only when they are gated.
  class ContactCollectionComponent < ViewComponent::Base
    def initialize(document:, url:)
      @document = document
      @url = url
    end

    attr_reader :document, :url

    def collection = Array(document["collection_ssim"]).first
    def contact = @contact ||= CollectionContact.for(collection)
    def title = Array(document["title_tsim"]).first.presence || document.id
    def accession_number = document.first("accession_number_ssim").presence

    # What the team calls the record: its UoM ID (RecordDocumentComponent), which is also the id in its link
    def persistent_id = CollectionIdentifier.uom_id(document.id)

    def mailto = contact.mailto(document: document, url: url)

    def request_access? = AccessPolicy.tier(document) != :open
    def request_access_path = AccessPolicy.request_path(document)
  end
end
