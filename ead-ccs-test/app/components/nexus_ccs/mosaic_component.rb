# frozen_string_literal: true

module NexusCcs
  # A mosaic of picture tiles led by one large tile (the homepage redesign, 2026-11; HomeSections gives the tiles). Each tile is one
  # link: the picture fills it and its name sits on the navy scrim (components/home_sections.css). The patterns place the tiles on a
  # 20-column grid from 840px, two columns from 600px, one below; the list is in reading order at every width:
  #
  #   five       four tiles, the lead last (right, two rows tall)          Explore the collections
  #   five_left  the lead first (left, two rows tall), four tiles          Visit the collections
  #   eight      seven tiles, the lead last (right, two rows tall)         Collections within the collections
  class MosaicComponent < ViewComponent::Base
    PATTERNS = %i[five five_left eight].freeze

    def initialize(tiles:, pattern:, label:)
      raise ArgumentError, "unknown pattern #{pattern.inspect}" unless PATTERNS.include?(pattern.to_sym)

      @tiles = tiles
      @pattern = pattern.to_sym
      @label = label
    end

    attr_reader :tiles, :pattern, :label

    def render? = tiles.any?
  end
end
