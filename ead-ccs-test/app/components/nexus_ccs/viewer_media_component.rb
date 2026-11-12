# frozen_string_literal: true

module NexusCcs
  # The viewer of the "viewer" record layout (?layout=viewer, RecordViewerComponent): the same media, with the same rules as
  # DigitalAssetsComponent (AccessPolicy: no asset path for a withheld or not-yet-chosen sensitive record, nothing that downloads
  # for a view-only one; Sensitivity: the choice notice stays inside the picture area), drawn as one grouped pill of four icon
  # controls at the picture's bottom right (zoom in, zoom out, reset, full screen), a counter badge, a strip of thumbnails, and one
  # quiet line under it with the keys the viewer takes and the download link (open records only). There is no mouse-wheel zoom:
  # the keys, the buttons, a double click and a pinch do (deep_zoom_viewer.js).
  class ViewerMediaComponent < DigitalAssetsComponent
    # What the viewer's canvas is described by, besides its name: the record's description, else its title
    def long_description = Array(@document["description_tsim"]).first.to_s.truncate(600, separator: " ").presence || title

    # "1 of 10"
    def counter(position) = t("nexus_ccs.record_page.viewer.counter", position: position, total: count)

    # Every image, in the strip, when there are several
    def strip? = count > 1

    # The one primary download of an open record: its first image, as the access card offered it
    def download_href = (main&.first if downloadable? && assets_shown?)
  end
end
