# frozen_string_literal: true

module NexusCcs
  # One record as a card, for the record page's Related objects, Similar records and Recently viewed. After the University
  # design system's Card and Listings: a 16:9 frame, a title that is an h3 and the link of the whole card (a stretched link, so
  # there is no nested link), and one quiet line (creator and date). The image is shown whole, never cropped (cultural material
  # is not cropped); a record with no image the visitor may see is a text card (a small kicker with its object type and collection,
  # the title, the creator and date), with no placeholder box.
  # The image rule is the result cards' (AccessPolicy, Sensitivity): no asset path of a withheld or sensitive record is in the markup.
  class RecordCardComponent < ViewComponent::Base
    UNKNOWN_MAKER = "Unknown"

    # compact: the quieter variant (Recently viewed): a smaller title and frame
    def initialize(document:, heading_tag: :h3, compact: false)
      @document = document
      @heading_tag = heading_tag
      @compact = compact
    end

    attr_reader :document, :heading_tag

    def compact? = @compact

    def title = Array(document["title_tsim"]).first.presence || document.id.to_s

    def path = helpers.solr_document_path(document)

    def image_path
      return @image_path if defined?(@image_path)

      @image_path = (AssetVersion.url(document["thumbnail_path_ssi"].presence) if AccessPolicy.view?(document) && !Sensitivity.sensitive?(document))
    end

    # The object type, else "Record"
    def type_label = Array(document["object_type_ssim"]).first.presence&.to_s&.upcase_first || "Record"

    # "Painting · University Art Collection"
    def kicker = [ type_label, Array(document["collection_ssim"]).first.presence ].compact.join(" · ")

    # The first named creator and the first date, as the record page's byline
    def meta
      creator = Array(document["creator_ssim"]).map(&:to_s).compact_blank.reject { |name| name == UNKNOWN_MAKER }.first
      [ creator, Array(document["production_date_ssim"]).first.presence ].compact.join(" · ")
    end

    def classes = [ "object-card", ("object-card--compact" if compact?), ("object-card--text" unless image_path) ].compact.join(" ")
  end
end
