# frozen_string_literal: true

module NexusCcs
  # Places on the home page (the homepage redesign, 2026-11): a list of places beside a large preview of one. Pointing at or focusing
  # a place shows its picture and description in the preview (place_preview_controller.js); every place is a link to its records.
  # Without JavaScript the first place is previewed and the list still links. On a narrow screen only the list shows.
  class PlacePreviewComponent < ViewComponent::Base
    def initialize(tiles:, label:)
      @tiles = tiles
      @label = label
    end

    attr_reader :tiles, :label

    def render? = tiles.any?

    def path(tile) = helpers.search_action_path(tile.query)

    # The places' pictures are the DAM's own thumbnails (full addresses), as on the Browse cards
    def image?(tile) = ExploreCardComponent.image?(tile, remote: true)

    def image_path(tile) = AssetVersion.url(tile.image.path)

    def count_label(tile) = t("home.records", count: tile.count, number: helpers.number_with_delimiter(tile.count))
  end
end
