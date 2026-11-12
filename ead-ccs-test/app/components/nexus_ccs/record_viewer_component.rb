# frozen_string_literal: true

module NexusCcs
  # The "viewer" layout of a record page, built after the user's Claude Design mockup (?layout=viewer on the record's own address;
  # off by default, so nothing changes for anyone else). The viewer is the left column (ViewerMediaComponent: the picture whole, one
  # grouped pill of icon controls, a counter, a strip of thumbnails, the keys it takes and the download link of an open record). The
  # right column is the record: kicker, a very large title, the byline, Save and a primary "Contact us" (or "Request access" for a
  # withheld record), the other actions as quiet text, then accordions (Object details, Collection and provenance, Rights and access,
  # About this record) and the persistent link in a tinted card. Below, a white band holds Related objects as three large cards.
  # Everything is the page's own: the same fields, rights, contact and access rules. Built on RecordDocumentComponent, whose
  # rows, chips, rights and debias scan it reuses; only the markup and the grouping differ.
  class RecordViewerComponent < RecordDocumentComponent
    # related: the record's Related objects (RelatedObjects), asked for once by the page; the white band shows the first three
    def initialize(related: [], **args)
      super(**args)
      @related = related
    end

    attr_reader :related

    # What "Collection and provenance" holds, of the fields the record has (the credit line is added by the template)
    PROVENANCE_FIELDS = %w[collection_ssim named_collection_ssim series_ssim associated_entity_ssim accession_number_ssim parent_record_ssi].freeze

    # Object details: everything else (the description is the first row, with its Show more)
    def detail_rows = all_rows.reject { |row| row.field.in?(PROVENANCE_FIELDS) }

    def provenance_rows = all_rows.select { |row| row.field.in?(PROVENANCE_FIELDS) }

    # Where the primary button goes: a withheld record asks for access; any other writes to the collection's team
    def contact
      @contact ||= CollectionContact.for(Array(document["collection_ssim"]).first)
    end

    def request_access? = AccessPolicy.tier(document) == :request

    def primary_label = t(request_access? ? "nexus_ccs.access_notice.request.link" : "nexus_ccs.record_page.viewer.contact")

    def primary_href
      return AccessPolicy.request_path(document) if request_access?
      return "/help#contact-us" unless contact

      contact.email? ? contact.mailto(document: document, url: helpers.solr_document_url(document)) : contact.url
    end

    def primary_new_tab? = !request_access? && contact&.form?

    # One quiet line under the buttons: what the visitor may do with the picture, and where to ask when it is more than they may
    def access_line = (t("nexus_ccs.record_page.viewer.access.#{AccessPolicy.tier(document)}") if assets?)

    # How many images Compare may use: those this visitor may see now
    def compare_images
      media = RecordMedia.for(document, session: helpers.session)
      media.shown? ? media.images.size : 0
    end

    def access_link? = assets? && AccessPolicy.tier(document) != :open && !request_access?
  end
end
