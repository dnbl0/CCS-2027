# frozen_string_literal: true

module NexusCcs
  # One Explore tile (a kind of record, a place or a period) drawn as the site's result card, so it sits in the same mosaic as the
  # results, Similar objects and Browse pages: the picture whole at its own shape when there is one, then the title, which is the one
  # link of the card. A tile with no picture is the "no media" card: its title only. The picture is the tile's example image, which
  # ExploreEntryPoints only ever keeps for a record anyone may download that is not sensitive (this is the second lock).
  class ExploreCardComponent < ViewComponent::Base
    def initialize(tile:, heading_tag: :h3, intro: nil, remote: false)
      @tile = tile
      @remote = remote
      @intro = intro
      @heading_tag = heading_tag
    end

    attr_reader :tile, :heading_tag, :intro

    # The Indigenous Collections tile is always text only (cultural review pending)
    def self.image?(tile, remote: false)
      prefixes = remote ? %w[/ http] : %w[/]
      tile.image.present? && tile.image.path.to_s.start_with?(*prefixes) && !ExploreEntryPoints.text_only?(tile.label)
    end

    # remote: the Browse cards' pictures are the DAM's own thumbnails, which have a full address and may have no known size
    def image? = self.class.image?(tile, remote: @remote)

    def size = tile.image.width ? { width: tile.image.width, height: tile.image.height } : {}

    def image_path = AssetVersion.url(tile.image.path)

    # The value's own page where it has one (a Browse card: a place, maker, subject or period), else its records in the search
    def path = (tile.path if tile.respond_to?(:path)).presence || helpers.search_action_path(tile.query)

    def classes = [ "result-card", "explore-card", ("explore-card--text" unless image?) ].compact.join(" ")
  end
end
