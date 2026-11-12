# frozen_string_literal: true

module NexusCcs
  # The "Zoom and pan" toggle and its viewer, over the record page's large image (CCS-57). Rendered by DigitalAssetsComponent
  # for the images it is showing only, so a withheld or not-yet-chosen sensitive record has none of its image sources in the
  # page. Behaviour: controllers/deep_zoom_controller.js (loads OpenSeadragon on first use). sources: [{ url:, info:, alt: }],
  # info being the IIIF info.json URL when the record carries one.
  class DeepZoomComponent < ViewComponent::Base
    # pill: the viewer layout's grouped controls (zoom in, zoom out, reset and, from the block, full screen) in place of the toggle
    # and the three labelled buttons; a press starts the viewer when it is not on yet
    # described_by: the id of a visually hidden long description the viewer's canvas points at (the pill layout)
    def initialize(sources:, label:, pill: false, described_by: nil)
      @sources = sources
      @label = label
      @pill = pill
      @described_by = described_by
    end

    attr_reader :described_by

    attr_reader :sources, :label

    def pill? = @pill

    def render? = sources.any?
  end
end
