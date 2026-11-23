# frozen_string_literal: true

module NexusCcs
  # A section's picture tiles as a fluid mosaic (the homepage redesign after Google Arts & Culture's mixed layouts, 2026-11; HomeSections
  # gives the tiles): every tile is the site's card in its tile variant, in lane masonry, its height following its picture, with no holes
  # and no picture cropped (mosaic_controller.js, components/home_sections.css). The first tile is the lead, two lanes wide, with its line
  # and call to action. lanes: how many lanes on a wide screen (fewer as it narrows).
  class MosaicComponent < ViewComponent::Base
    include AspectHelper

    # ordered: the tiles keep their order, row by row (a sequence: periods, eras; mosaic_controller's ordered lanes)
    def initialize(tiles:, label:, lanes: 4, ordered: false)
      @tiles = tiles
      @label = label
      @lanes = lanes
      @ordered = ordered
    end

    attr_reader :tiles, :label, :lanes, :ordered

    def item_style(tile) = aspect_style(tile.width, tile.height)

    def list_attributes = { class: "mosaic-flow", data: { controller: "mosaic", mosaic_lanes_value: lanes, mosaic_ordered_value: (true if ordered) }.compact }

    def render? = tiles.any?
  end
end
