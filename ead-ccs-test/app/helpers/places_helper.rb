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
end
