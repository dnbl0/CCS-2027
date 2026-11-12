# frozen_string_literal: true

module NexusCcs
  # The hero of the "viewer" record layout (?layout=viewer, RecordViewerComponent), after a product marketing page: the picture as the
  # hero object, whole and as large as fits, on a soft gradient, in one OpenSeadragon viewer that starts on load; three round navy buttons
  # at its bottom right (zoom in, zoom out, full view); round Previous and Next buttons at its edges and a row of small thumbnails
  # (Display image N of M) under it. It has the same rules as DigitalAssetsComponent (AccessPolicy: no asset path for a withheld or
  # not-yet-chosen sensitive record, nothing that downloads for a view-only one; Sensitivity: the choice notice stays inside the hero).
  # There is no mouse-wheel zoom: the keys, the buttons, a double click and a pinch do (deep_zoom_viewer.js), and the wheel scrolls the page.
  class ViewerMediaComponent < DigitalAssetsComponent
    # What the viewer's canvas is described by, besides its name: the record's description, else its title
    def long_description = Array(@document["description_tsim"]).first.to_s.truncate(600, separator: " ").presence || title

    # "Image 2 of 5", said politely when the image changes
    def counter(position) = t("nexus_ccs.record_page.viewer.counter", position: position, total: count)

    # "Display image 2 of 5": the name of a thumbnail
    def display_name(position) = t("nexus_ccs.record_page.viewer.display", position: position, total: count)

    # With several images: Previous, Next and every thumbnail
    def strip? = count > 1
  end
end
