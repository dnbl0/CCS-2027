# frozen_string_literal: true

module NexusCcs
  # A fanned stack of cards (after Google Arts & Culture's "SimpleStack", looked at 2026-11-24): one card at the centre at full size, the
  # others to either side, each step smaller (86%, 78%, 72%), further back and a little dimmer; pointing at a card or moving the focus to it
  # brings it to the centre (stack_controller.js). A card is a tall picture filling its frame, then its title and a line under it on
  # white; the whole card is its link. On a phone the stack is a row that scrolls sideways; without JavaScript, a plain row.
  # tiles: HomeSections::Tile (title, text, path, image). captions: false for Google's picture-only stack ("What do you want to explore?"):
  # a nearly square picture with no text under it, its name on a label in the picture's corner.
  class StackComponent < ViewComponent::Base
    def initialize(tiles:, label:, captions: true)
      @tiles = tiles
      @label = label
      @captions = captions
    end

    attr_reader :tiles, :label, :captions

    def render? = tiles.any?

    # The middle card starts at the centre
    def centre = tiles.size / 2
  end
end
