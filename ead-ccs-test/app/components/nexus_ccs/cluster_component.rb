# frozen_string_literal: true

module NexusCcs
  # A cluster of three or four pictures in one block (after Google Arts & Culture's "Clusters", looked at 2026-11-24): every card a
  # different size, so the block reads as one composition. Four: a tall card, a narrow tall card, then two wide cards one above the other
  # (Google's 858, 496 and 746 pixel columns); three: a large card and two wide cards stacked beside it (1200 and 838). Each picture fills
  # its card (cropped, as Google's are) and the title and a line under it sit on a navy shade at its foot; the whole card is its link.
  # On a phone: the first card the full width, the next two side by side, a fourth the full width again.
  # tiles: HomeSections::Tile (title, text, path, image); only those with a picture are shown, and fewer than three show nothing (the
  # caller then shows another layout).
  class ClusterComponent < ViewComponent::Base
    COUNTS = [ 3, 4 ].freeze

    def initialize(tiles:, label:)
      @tiles = tiles.select(&:image).first(COUNTS.max)
      @label = label
    end

    attr_reader :tiles, :label

    def render? = tiles.size >= COUNTS.min
  end
end
