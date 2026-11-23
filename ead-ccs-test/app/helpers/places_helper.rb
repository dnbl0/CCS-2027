# frozen_string_literal: true

# The Places page's tiles (browse/places): each place as a tile of the home page's mosaic (NexusCcs::MosaicComponent), its picture whole
# with its name and its full number of records under it, opening the place's own page
module PlacesHelper
  def place_tile(place, list)
    image = NexusCcs::ExploreCardComponent.image?(place, remote: true) ? place.image : nil
    count = list.count_of(place.label) || place.count
    HomeSections::Tile.new(title: place.label, text: t("home.records", count: count, number: number_with_delimiter(count)),
                           path: Browse.path_for("places", place.label) || search_action_path(place.query), image: image && DamImage.sized(AssetVersion.url(image.path), 600),
                           lead: false, cta: nil, external: false, width: image&.width, height: image&.height)
  end
end
