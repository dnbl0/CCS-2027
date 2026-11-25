# frozen_string_literal: true

module NexusCcs
  # A carousel of cards (after the National Gallery of Art's "Now on view" on its exhibition calendar, nga.gov/calendar?tab=exhibitions,
  # looked at 2026-11-25): a row of large cards that scrolls sideways, each snapping into place, the next one cut off at the edge, 20px
  # apart. A card: its picture at 4:3 filling its frame (on hover it slowly grows), its title in the heading face (on hover a line of the
  # brand colour grows under it), a bold line (meta: the number of records) and its words. The whole card is its link. Under the row, a
  # rule and the round previous and next buttons with "1 of 4" between them (carousel_controller.js); the left and right arrow keys move
  # the row too. Nothing moves on its own; every card stays reachable with the keyboard.
  # tiles: HomeSections::Tile (title, text, path, image); meta: a line for each tile, in order (or nil).
  class CardCarouselComponent < ViewComponent::Base
    def initialize(tiles:, label:, previous:, following:, meta: [])
      @tiles = tiles
      @label = label
      @previous = previous
      @following = following
      @meta = meta
    end

    attr_reader :tiles, :label, :previous, :following

    def meta(index) = @meta[index]

    def render? = tiles.any?
  end
end
