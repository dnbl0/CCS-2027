# frozen_string_literal: true

module NexusCcs
  # A carousel of large slides (after Google Arts & Culture's story carousel on a partner page, looked at 2026-11-24): each slide a
  # picture beside a panel of colour holding what kind of thing it is, its title, a line on it and what opening it does; the next slide
  # peeks in at the edge. The slides are a row that scrolls sideways with each slide snapping into place; the previous and next buttons
  # move one slide (carousel_controller.js) and are marked disabled at the ends. Nothing moves on its own. Every slide stays reachable with the
  # keyboard (moving the focus to its link scrolls it into view) and is named "2 of 4" (the ARIA carousel pattern).
  # tiles: HomeSections::Tile (title, text, path, image). kind: the label over each title ("Period"); cta: the words at its foot.
  class FeatureCarouselComponent < ViewComponent::Base
    def initialize(tiles:, label:, kind:, cta:, previous:, following:)
      @tiles = tiles
      @label = label
      @kind = kind
      @cta = cta
      @previous = previous
      @following = following
    end

    attr_reader :tiles, :label, :kind, :cta, :previous, :following

    def render? = tiles.any?
  end
end
