# frozen_string_literal: true

# blacklight-gallery's OpenSeadragon viewer (Blacklight::Gallery::OpenseadragonEmbedComponent) laid out as the CCS design's
# media viewer (Figma, "RecordTemplate"): a full-width dark band with the title, the image with round previous and next
# buttons either side and a row of 80px thumbnails, then a light toolbar with an info button and full screen (a modal of the
# record's media metadata) and full screen. The gem's component still does the viewing: its OpenSeadragon, its image
# sources, its page and full-page buttons (here Bootstrap buttons, found by the ids the gem gives them). The gem's own
# template is replaced by this component's, which sends the band to the layout (content_for :hero). No zoom (not in the
# first release): zoom buttons, mouse and keyboard navigation are off.
class StockOpenseadragonEmbedComponent < Blacklight::Gallery::OpenseadragonEmbedComponent
  IMAGES_FIELD = "digital_asset_large_paths_ssim"
  THUMBNAILS_FIELD = "digital_asset_paths_ssim"
  # What AccessPolicy lets the visitor do with the record's images: a :request record gets the notice in place of the viewer
  # (no image URL reaches the page), a :view_only record gets the viewer and the notice, an :open record the viewer alone.
  def tier = @tier ||= AccessPolicy.tier(presenter.document)
  def withheld? = tier == :request

  def osd_config
    super.except(:zoomInButton, :zoomOutButton, :homeButton).merge(
      showZoomControl: false, showHomeControl: false, mouseNavEnabled: false, keyboardNavEnabled: false,
      toolbar: "#{@id_prefix}-toolbar",
      # OpenSeadragon makes its viewer a tab stop; with the mouse and keyboard navigation off it does nothing and has no name (the thumbnails and
      # buttons are the controls), so it is left out of the tab order
      tabIndex: -1
    )
  end

  # Paging only: the gem's strip is not used (the thumbnails are drawn here)
  def osd_config_referencestrip = { sequenceMode: true }

  def image
    @image ||= begin
      urls = Array(presenter.document[IMAGES_FIELD]).compact_blank
      urls.map { |url| { url => { type: "image", url: url } } } if urls.any?
    end
  end

  # Small image for each large one, for the thumbnail row; the large one when there is no small one
  def thumbnails
    large = Array(presenter.document[IMAGES_FIELD]).compact_blank
    small = Array(presenter.document[THUMBNAILS_FIELD]).compact_blank
    large.each_with_index.map { |url, index| small[index].presence || url }
  end

  # The sheet's DAM fields (Licence Type, Advisory, Terms of Use, Producer): the media metadata
  def media_keys = StockRecordFields.media_keys

  def media_fields
    presenter.field_presenters.select { |field| media_keys.include?(field.key) }
  end

  # The text alternative of the image on show (the viewer draws it on a canvas, which has none): the title, and which image of how many
  def image_label(number)
    count > 1 ? "#{presenter.heading}, image #{number} of #{count}" : presenter.heading
  end

  def viewer_id = "#{@id_prefix}-viewer"
end
