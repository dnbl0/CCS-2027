# frozen_string_literal: true

module NexusCcs
  # A record's media on its page, after the CCS UI "Record-detail" media section: a dark band with the large
  # image (a row of thumbnails under it when there are several), a "Media metadata" panel that slides over the
  # band's right edge, and a toolbar with the licence and the buttons for that panel and for full screen.
  # Renders nothing for a record without assets. What it shows follows AccessPolicy: all of it for :open; for :view_only no
  # download (the media players' download button, the PDF link and the thumbnails' links to the files go) and a notice; for
  # :request none of the assets, only the notice, the licence and the media metadata. Registered, through NexusCcs::RecordEmbedComponent, as the show
  # page's document_embed_component. Behaviour: controllers/media_viewer_controller.js.
  class DigitalAssetsComponent < Blacklight::Component
    # The advisory every record carries (the demo's wording)
    ADVISORY = "Some collection items include terms and views that are not appropriate today. They reflect the " \
               "period in which they were created and are not the views of the University of Melbourne."

    ICONS = %w[media-copyright media-info media-fullscreen].freeze

    def initialize(presenter:, document_counter: nil, **)
      @document = presenter.document
      @tier = AccessPolicy.tier(@document)
    end

    attr_reader :tier

    # The record has assets, whether or not the policy lets them be shown
    def render?
      Array(@document["digital_asset_large_paths_ssim"]).any? || Array(@document["digital_media_ssim"]).any?
    end

    def withheld? = tier == :request
    def downloadable? = tier == :open

    # Audio, video and PDF files: [{ kind:, type:, url:, label: }]. A PDF can only be read by opening the file, so it is
    # left out when the file may not be downloaded.
    def media
      return [] if withheld?

      items = Array(@document["digital_media_ssim"]).map { |entry| Collections::DigitalMedia.parse(entry) }
      downloadable? ? items : items.select { |item| %w[video audio].include?(item[:kind]) }
    end

    # Pairs of [large image path, thumbnail path], in display order.
    def images
      large_paths.zip(thumbnail_paths)
    end

    def main = images.first
    def media_title(item) = item[:label].presence || title
    def others = images.drop(1)

    def count = large_paths.size

    def title
      Array(@document["title_tsim"]).first.presence || "Record"
    end

    # The image name carries the title and position, so each one is distinguishable.
    def alt(position)
      count == 1 ? title : "#{title}, image #{position} of #{count}"
    end

    # e.g. "Copyright - Current"; the toolbar shows it as the licence chip
    def licence
      Array(@document["licence_type_ssim"]).first.presence
    end

    # What the record's rights note says (the licence name in brackets is the chip's, so it is not repeated)
    def terms
      note = Array(@document["rights_ssim"]).first.to_s.sub(/\A\s*\[[^\]]*\]\s*/, "").strip
      note.presence
    end

    # Person or organisation responsible for creating the digital asset (DataModel field 30; no DAM export yet)
    def producer
      Array(@document["producer_ssim"]).first.presence
    end

    # [label, text] rows of the Media metadata panel
    def metadata
      [ [ "Licence type", licence ], [ "Advisory", ADVISORY ], [ "Terms of use", terms ], [ "Producer", producer ] ].select { |_, text| text.present? }
    end

    def metadata?
      metadata.any?
    end

    # An icon from app/assets/images, drawn in the text colour (the files carry the design's fixed navy)
    def icon(name)
      raise ArgumentError, name unless ICONS.include?(name)

      File.read(Rails.root.join("app/assets/images/#{name}.svg"))
          .gsub(/ (width|height|style|preserveAspectRatio|overflow)="[^"]*"/, "")
          .gsub(/ clip-path="[^"]*"/, "")
          .gsub(/ id="[^"]*"/, "")
          .gsub(/(stroke|fill)="#(?:[0-9A-Fa-f]{3,6})"/, '\1="currentColor"')
          .sub("<svg", '<svg width="1em" height="1em" aria-hidden="true" focusable="false"')
          .html_safe
    end

    private

    # Nothing of a withheld asset reaches the page, not even as a path
    def large_paths = withheld? ? [] : Array(@document["digital_asset_large_paths_ssim"])
    def thumbnail_paths = withheld? ? [] : Array(@document["digital_asset_paths_ssim"])
  end
end
