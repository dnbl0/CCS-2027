# frozen_string_literal: true

module NexusCcs
  # A record's media on its page, the left of the approved split layout (Figma "Object viewer"): the large image shown whole at its
  # own shape, a controls row under it (the licence and access chips on the left; round zoom in, zoom out, full screen and, for an
  # open image, download on the right) and, when there are several images, a strip of every thumbnail with previous and next. The
  # media metadata is the record column's "Media details" section (#metadata). Renders nothing for a record without assets. What it shows follows AccessPolicy, asset by asset: the index holds only
  # the assets a visitor may see (Dam::SolrWriter), and of those only an open one is offered to download (its thumbnail links to
  # the file, its player keeps its download button, a PDF is listed); a view-only one is shown without any of that. A record
  # with some assets withheld says so under them, with a request link; a :request record shows none of the assets, only the
  # notice, the licence and the media metadata. A sensitive record's assets are
  # shown only after the visitor chooses to view them (SensitivityGateComponent). Registered, through NexusCcs::RecordEmbedComponent, as the show
  # page's document_embed_component. Behaviour: controllers/media_viewer_controller.js.
  class DigitalAssetsComponent < Blacklight::Component
    # The advisory every record carries (the demo's wording)
    ADVISORY = "Some collection items include terms and views that are not appropriate today. They reflect the " \
               "period in which they were created and are not the views of the University of Melbourne."


    def initialize(presenter:, document_counter: nil, **)
      @document = presenter.document
      @tier = AccessPolicy.tier(@document)
    end

    attr_reader :tier

    # The record has assets, whether or not the policy lets them be shown
    def render? = RecordMedia.assets?(@document)

    def withheld? = tier == :request

    # How many of the record's assets are withheld while the others are shown (AccessPolicy.withheld_assets); 0 while the
    # visitor has not chosen to view a sensitive record (nothing is shown yet)
    def withheld_count = assets_shown? ? AccessPolicy.withheld_assets(@document) : 0
    def request_path = AccessPolicy.request_path(@document)

    # May the image at this position (0 is the main one) be downloaded: is it an open asset (AccessPolicy.download_path?)
    def image_downloadable?(index) = AccessPolicy.download_path?(@document, raw_large_paths[index])

    # A sensitive record's assets wait for the visitor's choice (Sensitivity, CCS-227): :ask, :declined or :viewing; nil for
    # any other record, and for one that is withheld anyway. Until the choice is "view", none of the assets is on the page.
    def sensitivity_state
      return @sensitivity_state if defined?(@sensitivity_state)

      @sensitivity_state = if withheld? || !Sensitivity.sensitive?(@document) then nil
      else
        choices = Sensitivity::Choices.new(helpers.session)
        if choices.viewing?(@document.id) then :viewing
        elsif choices.declined?(@document.id) then :declined
        else :ask
        end
      end
    end

    def gated? = %i[ask declined].include?(sensitivity_state)
    def assets_shown? = !withheld? && !gated?

    # Audio, video and PDF files: [{ kind:, type:, url:, label:, downloadable: }] (downloadable: an open asset, AccessPolicy.download_path?).
    # A PDF can only be read by opening the file, so it is
    # left out when the file may not be downloaded.
    def media
      return [] unless assets_shown?

      items = Array(@document["digital_media_ssim"]).map { |entry| Collections::DigitalMedia.parse(entry) }
                                                    .map { |item| item.merge(downloadable: AccessPolicy.download_path?(@document, item[:url])) }
                                                    .map { |item| item.merge(url: AssetVersion.url(item[:url]), captions: AssetVersion.url(item[:captions]), transcript: AssetVersion.url(item[:transcript])) }
      items.select { |item| item[:downloadable] || %w[video audio].include?(item[:kind]) }
    end

    # Pairs of [large image path, thumbnail path], in display order.
    def images
      large_paths.zip(thumbnail_paths)
    end

    def main = images.first

    # What the zoom viewer may open: the images being shown (none when they are withheld or waiting for a choice), with the
    # IIIF info.json of each when the record has one (MediaTypes::IIIF_INFO_FIELD, parallel to the large images)
    def zoom_sources
      infos = Array(@document[MediaTypes::IIIF_INFO_FIELD])
      images.each_with_index.map { |(large, _thumbnail), index| { url: large, info: infos[index].presence, alt: alt(index + 1) } }
    end


    def access_chip = t("nexus_ccs.record_page.access.#{tier}")

    # The one primary action: the main image, to download, when it is an open asset (never a view-only or withheld one: no path is in the markup)
    def download_href = (main&.first if assets_shown? && image_downloadable?(0))

    # The image's width and height attributes (nothing when its size is not known), so the page holds its space while it loads: read
    # from the file when it is on this server, or the DAM image's size once it has been read for the IIIF manifest (only the kept
    # size: drawing the page never asks the DAM)
    def image_size(path)
      width, height = ImageDimensions.for_path(path) || RemoteImageDimensions.cached(path)
      width ? { width: width, height: height } : {}
    end

    # "800 / 1200" for the main image when its size is known, else nil
    def ratio
      size = image_size(main.first)
      "#{size[:width]} / #{size[:height]}" if size[:width]
    end

    def media_title(item) = item[:label].presence || title

    def count = large_paths.size

    def title
      Array(@document["title_tsim"]).first.presence || "Record"
    end

    # The image name carries the title and position, so each one is distinguishable.
    def alt(position)
      count == 1 ? title : "#{title}, image #{position} of #{count}"
    end

    # The DAM's licence (DA License Type) when the record has DAM assets, else the EMu licence, e.g. "Copyright - Current";
    # the toolbar shows it as the licence chip
    def licence
      dam_value("licence") || Array(@document["licence_type_ssim"]).first.presence
    end

    # The DAM's DA Terms of Use, else what the record's rights note says (the licence name in brackets is the chip's, so it is
    # not repeated)
    def terms
      dam_value("terms_of_use") || Array(@document["rights_ssim"]).first.to_s.sub(/\A\s*\[[^\]]*\]\s*/, "").strip.presence
    end

    # Person or organisation responsible for creating the digital asset (DataModel field 30): the DAM's DA Creator Name (Role)
    def producer
      dam_value("producer") || Array(@document["producer_ssim"]).first.presence
    end

    # The DAM's DA Advisory, else the advisory every record carries
    def advisory = dam_value("advisory") || ADVISORY

    # [label, text] rows of the record column's "Media details" section (RecordDocumentComponent)
    def metadata
      [ [ "Licence type", licence ], [ "Advisory", advisory ], [ "Terms of use", terms ], [ "Producer", producer ] ].select { |_, text| text.present? }
    end

    # The first non-blank value of a DAM field across the record's assets (digital_asset_metadata_ssm, written by Dam::SolrWriter):
    # the shown assets' first, so the licence beside an image is a shown asset's, not a withheld one's
    def dam_value(key)
      @dam_metadata ||= begin
        all = Array(@document["digital_asset_metadata_ssm"]).filter_map do |json|
          parsed = JSON.parse(json.to_s)
          parsed if parsed.is_a?(Hash)
        rescue JSON::ParserError
          nil
        end
        tiers = AccessPolicy.asset_tiers(@document) || []
        shown, withheld = all.each_with_index.partition { |_asset, index| tiers[index] && tiers[index] != :request }
        (shown + withheld).map(&:first)
      end
      @dam_metadata.filter_map { |asset| asset[key].to_s.strip.presence }.first
    end
    private :dam_value

    def glyph(name) = Glyphs.svg(name)

    private

    # Nothing of a withheld asset (or one the visitor has not chosen to view) reaches the page, not even as a path
    # (and the addresses carry a version token, AssetVersion, so a replaced file is fetched again)
    def raw_large_paths = assets_shown? ? Array(@document["digital_asset_large_paths_ssim"]) : []
    def large_paths = raw_large_paths.map { |path| AssetVersion.url(path) }
    def thumbnail_paths = assets_shown? ? Array(@document["digital_asset_paths_ssim"]).map { |path| AssetVersion.url(path) } : []
  end
end
