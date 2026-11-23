# frozen_string_literal: true

module NexusCcs
  # A section's picture tiles as a fluid mosaic (the homepage redesign after Google Arts & Culture's mixed layouts, 2026-11; HomeSections
  # gives the tiles): every tile is the site's card in its tile variant, in lane masonry, its height following its picture, with no holes
  # and no picture cropped (mosaic_controller.js, components/home_sections.css). The first tile is the lead, two lanes wide, with its line
  # and call to action. lanes: how many lanes on a wide screen (fewer as it narrows).
  class MosaicComponent < ViewComponent::Base
    include AspectHelper

    # even: every tile one shape (4:3, each picture whole on its mount) in a plain grid whose rows share a height, so the tiles read in their
    # order, row by row: true for a sequence (periods); :auto when fewer than half the tiles have a picture (a few tall pictures among
    # text tiles would leave the mosaic full of holes)
    def initialize(tiles:, label:, lanes: 4, even: false)
      @tiles = tiles
      @label = label
      @lanes = lanes
      @even = even == :auto ? tiles.count(&:image) * 2 < tiles.size : even
    end

    attr_reader :tiles, :label, :lanes, :even

    def item_style(tile) = even ? "--a: 1.333" : aspect_style(tile.width, tile.height)

    def list_attributes
      even ? { class: "mosaic-flow mosaic-flow--even" } : { class: "mosaic-flow", data: { controller: "mosaic", mosaic_lanes_value: lanes } }
    end

    def render? = tiles.any?
  end
end
