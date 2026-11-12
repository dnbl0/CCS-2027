# frozen_string_literal: true

module NexusCcs
  # The "viewer" layout of a record page (?layout=viewer on the record's own address; off by default, so nothing changes for anyone
  # else), after a museum object page: a split screen under the site header, the data panel on the left (the title, the record's rows as
  # label above value, in sections) and one big viewer on the right (ViewerMediaComponent), a round toggle on the dividing line that
  # collapses the panel, a dark strip of thumbnails under the viewer, and a teal bar under the panel with New search, Share and
  # Print. Below 1024px the two are two views, Show images and Show data. Everything is the page's own: the same fields, rights, contact
  # and access rules; only the markup and the grouping differ. Built on RecordDocumentComponent, whose rows, chips, rights and de-bias
  # scan it reuses. Related objects and More like this follow below the split, full width, as on the plain page.
  class RecordViewerComponent < RecordDocumentComponent
    # What "Collection and provenance" holds, of the fields the record has (the credit line is added by the template)
    PROVENANCE_FIELDS = %w[collection_ssim named_collection_ssim series_ssim associated_entity_ssim accession_number_ssim parent_record_ssi].freeze

    # Object details: everything else (the description is the first row, with its Show more)
    def detail_rows = all_rows.reject { |row| row.field.in?(PROVENANCE_FIELDS) }

    def provenance_rows = all_rows.select { |row| row.field.in?(PROVENANCE_FIELDS) }

    # How many images Compare may use: those this visitor may see now
    def compare_images
      media = RecordMedia.for(document, session: helpers.session)
      media.shown? ? media.images.size : 0
    end
  end
end
