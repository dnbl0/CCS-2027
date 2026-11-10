# frozen_string_literal: true

module NexusCcs
  # The home page's "Explore the collections" section. A Fraunces H2 and one line, then three groups (ExploreEntryPoints, config/explore_kinds.yml):
  #   1. "Browse by collection": one tile per collection, as the University's Listings component (16:10 face, the whole tile is the one link,
  #      its title an H3 inside the link, the exact count in the same link). A tile's face is a tinted, typographic one by default; an example
  #      image replaces it only when ExploreEntryPoints kept one (open, not sensitive, a held thumbnail), shown whole. On a phone a tile is a row.
  #   2. "Kinds of records": a plain grouped list of arrow links, as on the University Library's collections page.
  #   3. "Place and time": two short lists of arrow links in disclosures (closed on a phone), each with a "See all" link to its browse page.
  # Renders nothing when there is nothing to show (Solr down and nothing kept).
  class ExploreComponent < ViewComponent::Base
    def initialize(overview: ExploreEntryPoints.overview)
      @overview = overview
    end

    attr_reader :overview

    def render? = overview.any?

    def count_label(count) = t("explore.count", count: count, number: helpers.number_with_delimiter(count))

    # The first letter of the collection's name: the typographic face of a tile with no picture (decoration, hidden from assistive technology)
    def monogram(tile) = tile.label.to_s.strip[0].to_s.upcase

    # Whether the tile has a picture to draw. The picture is a record's thumbnail, so only a record whose asset anyone may download and that
    # is not sensitive is ever given here (ExploreEntryPoints); this is the second lock, not the only one. The Indigenous Collections tile is
    # always text only (cultural review pending).
    def image?(tile) = tile.image.present? && tile.image.path.to_s.start_with?("/") && !ExploreEntryPoints.text_only?(tile.label)

    def image_path(tile) = AssetVersion.url(tile.image.path)
  end
end
