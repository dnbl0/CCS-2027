# frozen_string_literal: true

module NexusCcs
  # The right pane of the "viewer" record layout (?layout=viewer, RecordViewerComponent), after a museum object viewer: one big stage
  # that a single OpenSeadragon viewer fills (it starts on load), three round dark buttons at its bottom right (zoom in, zoom out, full
  # screen), and a dark strip under it with Previous, the thumbnails, Next and "Use this image". It has the same rules as
  # DigitalAssetsComponent (AccessPolicy: no asset path for a withheld or not-yet-chosen sensitive record, nothing that downloads for a
  # view-only one; Sensitivity: the choice notice stays inside the stage). There is no mouse-wheel zoom: the keys, the buttons, a double
  # click and a pinch do (deep_zoom_viewer.js), and the wheel scrolls the page.
  class ViewerMediaComponent < DigitalAssetsComponent
    # What the viewer's canvas is described by, besides its name: the record's description, else its title
    def long_description = Array(@document["description_tsim"]).first.to_s.truncate(600, separator: " ").presence || title

    # "Image 2 of 5", said politely when the image changes
    def counter(position) = t("nexus_ccs.record_page.viewer.counter", position: position, total: count)

    # "Display image 2 of 5": the name of a thumbnail
    def display_name(position) = t("nexus_ccs.record_page.viewer.display", position: position, total: count)

    # With several images: Previous, Next and every thumbnail
    def strip? = count > 1

    # What "Use this image" does: an open record downloads the current image; a view-only record goes to its rights; a withheld one
    # asks for access. Nothing for a record whose image is not shown, and never an asset path for any tier but open.
    def use_image
      if downloadable? && assets_shown? && main then [ :download, main.first ]
      elsif tier == :view_only && assets_shown? then [ :rights, "#viewer-rights" ]
      elsif tier == :request then [ :request, AccessPolicy.request_path(@document) ]
      end
    end
  end
end
