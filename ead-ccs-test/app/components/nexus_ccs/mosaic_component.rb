# frozen_string_literal: true

module NexusCcs
  # A section's picture tiles as a fluid mosaic (the homepage redesign after Google Arts & Culture's mixed-size layouts, 2026-11;
  # HomeSections gives the tiles): every tile is the site's card in its tile variant, its width chosen from its picture's shape and its
  # height following the picture, packed so tiles of different sizes interlock; no picture is cropped (mosaic_controller.js,
  # components/home_sections.css). The first tile is the lead, wider, with its line and call to action. base: a tile's width in
  # columns of 12 for a square picture (the section's density).
  class MosaicComponent < ViewComponent::Base
    include AspectHelper

    def initialize(tiles:, label:, base: 4)
      @tiles = tiles
      @label = label
      @base = base
    end

    attr_reader :tiles, :label, :base

    def render? = tiles.any?
  end
end
