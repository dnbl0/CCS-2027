# frozen_string_literal: true

module NexusCcs
  # A section's picture tiles as a fluid mosaic (the homepage redesign after Google Arts & Culture's mixed layouts, 2026-11; HomeSections
  # gives the tiles): every tile is the site's card in its tile variant, in lane masonry, its height following its picture, with no holes
  # and no picture cropped (mosaic_controller.js, components/home_sections.css). The first tile is the lead, two lanes wide, with its line
  # and call to action. lanes: how many lanes on a wide screen (fewer as it narrows).
  class MosaicComponent < ViewComponent::Base
    include AspectHelper

    def initialize(tiles:, label:, lanes: 4)
      @tiles = tiles
      @label = label
      @lanes = lanes
    end

    attr_reader :tiles, :label, :lanes

    def render? = tiles.any?
  end
end
