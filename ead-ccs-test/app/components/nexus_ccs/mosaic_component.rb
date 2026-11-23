# frozen_string_literal: true

module NexusCcs
  # A section's picture tiles in justified rows (the homepage redesign, 2026-11; HomeSections gives the tiles): every tile is the site's
  # card in its tile variant, as wide as its picture's shape at the row's height, so each picture shows whole (never cropped) and each
  # row fills the width (justified_controller.js, components/home_sections.css). The first tile is the lead, with its line and call to
  # action. The list is in reading order at every width.
  class MosaicComponent < ViewComponent::Base
    include AspectHelper

    def initialize(tiles:, label:)
      @tiles = tiles
      @label = label
    end

    attr_reader :tiles, :label

    def render? = tiles.any?
  end
end
