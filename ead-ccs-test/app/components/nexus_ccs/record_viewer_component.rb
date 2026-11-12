# frozen_string_literal: true

module NexusCcs
  # The "viewer" layout of a record page (?layout=viewer on the record's own address; off by default, so nothing changes for anyone
  # else), styled as a product marketing page: a full-width hero with the picture as the hero object (ViewerMediaComponent), a local
  # navigation that sticks once the hero is past, a headline block with a big title and a pill card, then bands that alternate white and
  # grey: highlights (the description and a scroller of cards, one per image), details, rights, about, and related records. Everything
  # is the page's own: the same fields, rights, contact and access rules; only the markup and the grouping differ. Built on
  # RecordDocumentComponent, whose rows, chips, rights and de-bias scan it reuses.
  class RecordViewerComponent < RecordDocumentComponent
    # What "Collection and provenance" holds, of the fields the record has (the credit line is added by the template)
    PROVENANCE_FIELDS = %w[collection_ssim named_collection_ssim series_ssim associated_entity_ssim accession_number_ssim parent_record_ssi].freeze

    # Object details: everything else but the description (which is the highlights' paragraph)
    def detail_rows = all_rows.reject { |row| row.field.in?(PROVENANCE_FIELDS) || row.field == DESCRIPTION_FIELD }

    def provenance_rows = all_rows.select { |row| row.field.in?(PROVENANCE_FIELDS) }

    def tier = AccessPolicy.tier(document)

    def media = @media ||= RecordMedia.for(document, session: helpers.session)

    # The pictures this visitor may see now, for the cards (none for a withheld or not-yet-chosen sensitive record)
    def card_images = media.shown? ? media.images : []

    # How many images Compare may use: those this visitor may see now
    def compare_images = card_images.size

    # The one navy pill button, in the local navigation and the pill card: an open record's image to download, a withheld record's request
    # for access, and for any other record (view-only, no media) a message to the collection's team
    def primary
      @primary ||= if assets? && tier == :open && media.images.first then { kind: :download, href: media.images.first.url }
      elsif assets? && tier == :request then { kind: :request, href: AccessPolicy.request_path(document) }
      else { kind: :contact, href: contact_href }
      end
    end

    def primary_new_tab? = primary[:kind] == :contact && contact&.form?

    # The collection's team, as the page's other contact links reach it
    def contact = @contact ||= CollectionContact.for(Array(document["collection_ssim"]).first)

    def contact_href
      return "/help#contact-us" unless contact

      contact.email? ? contact.mailto(document: document, url: helpers.solr_document_url(document)) : contact.url
    end

    # The line in the pill card: what the visitor may do with the picture; none for a record with no media
    def status_line = (t("nexus_ccs.record_page.viewer.status.#{tier}") if assets?)

    # How to use the image, said in the rights band, per tier
    def use_text = t("nexus_ccs.record_page.viewer.use.#{assets? ? tier : :none}")

    def local_links
      [ [ t("nexus_ccs.record_page.subnav.overview"), "#viewer-overview" ],
        [ t("nexus_ccs.record_page.viewer.details_link"), "#viewer-details" ],
        [ t("nexus_ccs.record_page.viewer.rights_link"), "#viewer-rights" ],
        (Discovery.listable?(document) ? [ t("nexus_ccs.record_page.viewer.related_link"), "#more-like-this" ] : nil) ].compact
    end
  end
end
