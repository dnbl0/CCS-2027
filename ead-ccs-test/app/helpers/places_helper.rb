# frozen_string_literal: true

# The Browse pages' tiles (browse/hub): each value as a tile of the home page's mosaic (NexusCcs::MosaicComponent), its picture whole with
# its name and its number of records under it, opening its own page (a place, maker, subject or period) or else its records in the search
module PlacesHelper
  def hub_tile(card, list)
    image = NexusCcs::ExploreCardComponent.image?(card, remote: true) ? card.image : nil
    count = list.count_of(card.label) || card.count
    HomeSections::Tile.new(title: card.label, text: t("home.records", count: count, number: number_with_delimiter(count)),
                           path: card.path || search_action_path(card.query), image: image && DamImage.sized(AssetVersion.url(image.path), 600),
                           lead: false, cta: nil, external: false, width: image&.width, height: image&.height)
  end

  # Explore by place's pins (place_explorer_controller.js): every place on the map, with its region and line, and for a place with a card
  # (Explore::PlaceCards) its own page and a small picture for its popup; any other place opens its records in the search
  def place_explorer_markers(places, cards)
    by_key = cards.index_by(&:key)
    places.markers.each_with_index.map do |marker, key|
      card = by_key[key]
      picture = DamImage.sized(AssetVersion.url(card.image.path), 400) if card && NexusCcs::ExploreCardComponent.image?(card, remote: true)
      { key: key, label: marker.label, where: Explore::PlaceCards.where(marker.path), region: Explore::PlaceCards.region(marker.path),
        lat: marker.lat, lon: marker.lon, count: marker.count, href: card&.path || search_action_path(marker.search_query), card: card.present?, image: picture }
    end
  end

  # A category's value (Categories::Tile) as a mosaic tile: a collection or named collection opens its own page
  def category_tile(tile, dimension)
    image = NexusCcs::ExploreCardComponent.image?(tile, remote: true) ? tile.image : nil
    image ||= collection_tile_picture(tile.value) if dimension.slug == "collections" # the home page's picture of the collection
    path = (dimension.landing? && landing_path_for(dimension.slug, tile.value)) || search_action_path(tile.query)
    HomeSections::Tile.new(title: tile.value.to_s.upcase_first, text: t("home.records", count: tile.count, number: number_with_delimiter(tile.count)),
                           path: path, image: image && DamImage.sized(AssetVersion.url(image.path), 600),
                           lead: false, cta: nil, external: false, width: image&.width, height: image&.height)
  end

  def collection_tile_picture(name)
    @collection_tile_pictures ||= ExploreEntryPoints.overview.collections.to_h { |tile| [ tile.label, (tile.image if NexusCcs::ExploreCardComponent.image?(tile)) ] }
    @collection_tile_pictures[name]
  end

  # The Themes and Stories pages: each as a mosaic tile with its hero record's picture (when that record may be shown), its words and its
  # own page. items: Themes::Theme or Stories::Story; text: the line under the name
  # fallback: a lambda giving a picture for an item whose hero may not be shown (a theme: its first highlight)
  def discovery_tiles(items, text:, fallback: nil)
    heroes = hero_pictures(items.filter_map(&:hero))
    items.map do |item|
      picture = heroes[item.hero] || fallback&.call(item)
      HomeSections::Tile.new(title: item.title, text: text.call(item), path: item.path, image: picture && DamImage.sized(AssetVersion.url(picture), 900),
                             lead: false, cta: nil, external: false, width: nil, height: nil)
    end
  end

  # { record id => thumbnail path } for the records that may be shown (Showcase.shown?: licensed and not sensitive), in one request
  def hero_pictures(ids)
    return {} if ids.empty?

    Array(Discovery.fetch(ids.uniq)).select { |document| Showcase.shown?(document) && document["thumbnail_path_ssi"].present? }
                                   .to_h { |document| [ document.id.to_s, document["thumbnail_path_ssi"] ] }
  rescue *SolrGuard::FAILURES, SolrGuard::Unavailable
    {}
  end

  # A theme's first highlight with a picture (the theme page's own Showcase request, so it is cached and shared)
  def theme_picture(theme)
    found = Showcase.call(fq: theme.fq, first: theme.hero, highlights: Showcase::PAGE_HIGHLIGHTS)
    Array(found&.documents).find { |document| document["thumbnail_path_ssi"].present? }&.then { |document| document["thumbnail_path_ssi"] }
  end
end
