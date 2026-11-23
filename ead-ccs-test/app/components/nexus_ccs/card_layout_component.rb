# frozen_string_literal: true

module NexusCcs
  # A section's cards (ExploreCardComponent) in one of the layouts of components/card_layouts.css, so the page's sections are not all the
  # same grid (docs/card-layouts.md):
  #
  #   bento  a feature card two cells wide and tall beside smaller ones
  #   rail   a row that scrolls sideways, the next card peeking, with round previous and next buttons
  #   strip  a row in which the card the visitor points at or focuses widens (the first one at rest); a grid on a phone
  #   grid   an even grid of square pictures
  #   wall   an even grid with a brand panel (after the first card) that opens the full list
  #   shelf  a row of pictures shown whole at one height, each as wide as its shape, the name under it; it scrolls sideways like
  #          the rail (the homepage redesign's Record types)
  #   justified  rows in which every card is as wide as its picture's shape at the row's height, so no picture is cropped and each row
  #          fills the width (justified_controller.js measures a picture whose size is not known)
  #
  # The picture is always whole (never cropped) on a mat, so no layout needs to know the picture's shape. Layout is only CSS (and the
  # rail's buttons); the markup is a plain list of cards in every layout, so it reads the same to a screen reader.
  class CardLayoutComponent < ViewComponent::Base
    include AspectHelper
    LAYOUTS = %i[bento rail strip grid wall shelf justified].freeze
    WALL_AFTER = 1 # the wall's panel comes after this many cards, so the reading order follows the picture

    # cards: anything with label, query, image and intro (nil for none); panel: { title:, text:, link:, path: } for the wall;
    # renderer: a lambda giving the component for one card, for cards that are not Explore tiles (the home page's record cards)
    def initialize(cards:, layout:, label:, panel: nil, renderer: nil)
      raise ArgumentError, "unknown layout #{layout.inspect}" unless LAYOUTS.include?(layout.to_sym)

      @cards = cards
      @layout = layout.to_sym
      @label = label
      @panel = panel
      @renderer = renderer
    end

    def card_component(card) = @renderer ? @renderer.call(card) : ExploreCardComponent.new(tile: card, intro: card.intro, remote: true)

    attr_reader :cards, :layout, :label, :panel

    def rail? = %i[rail shelf].include?(layout)

    def wall? = layout == :wall && panel.present?

    def justified? = layout == :justified

    # A justified item's shape, when its picture's size is known (an Explore tile's image); otherwise the controller measures it
    def item_style(card)
      return nil unless justified? && card.respond_to?(:image) && card.image

      aspect_style(card.image.width, card.image.height)
    end

    # [[:card, card], ...] with the wall's [:panel, panel] after the WALL_AFTER-th card
    def items
      list = cards.map { |card| [ :card, card ] }
      list.insert(WALL_AFTER, [ :panel, panel ]) if wall?
      list
    end
  end
end
