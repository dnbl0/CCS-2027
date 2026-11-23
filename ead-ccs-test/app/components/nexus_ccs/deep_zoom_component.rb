# frozen_string_literal: true

module NexusCcs
  # The zoom viewer inside the record page's zoom modal (CCS-57). Rendered by DigitalAssetsComponent
  # for the images it is showing only, so a withheld or not-yet-chosen sensitive record has none of its image sources in the
  # page. Behaviour: controllers/deep_zoom_controller.js (loads OpenSeadragon on first use). sources: [{ url:, info:, alt: }],
  # info being the IIIF info.json URL when the record carries one.
  class DeepZoomComponent < ViewComponent::Base
    def initialize(sources:, label:)
      @sources = sources
      @label = label
    end

    attr_reader :sources, :label

    def render? = sources.any?
  end
end
