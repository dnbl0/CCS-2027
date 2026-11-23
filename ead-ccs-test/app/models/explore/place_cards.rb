# frozen_string_literal: true

module Explore
  # The cards of Explore by place, beside its map (after Airbnb's search with a map, 2026-11): the places with the most pictured records
  # (Browse::Cards.map_cards), each joined by name to its pin on the map (Explore::Places::Marker), so the card knows where it is, the
  # region it belongs to and the line under its name ("Victoria, Australia"). A place with no pin is left out: the list follows the map.
  # The number is the pin's (every record from the place and the places in it), so a card and its pin say the same.
  module PlaceCards
    Item = Data.define(:key, :label, :where, :count, :image, :path, :region)

    # places: Explore::Places::Result; cards: Browse::Cards::Card
    def self.for(places, cards = Browse::Cards.map_cards(BrowseHubs.find("places")))
      return [] unless places&.map?

      keys = places.markers.each_with_index.group_by { |marker, _| marker.label.downcase }
                   .transform_values { |pairs| pairs.max_by { |marker, _| marker.count } }
      used = Set.new
      cards.filter_map do |card|
        marker, key = keys[card.label.downcase]
        next if marker.nil? || !used.add?(key)

        Item.new(key: key, label: marker.label, where: where(marker.path), count: marker.count, image: card.image, path: card.path, region: region(marker.path))
      end
    end

    # "Oceania|Australia|Victoria|Melbourne" => "Victoria, Australia"; a country => its region
    def self.where(path)
      segments = path.split(Geo::Hierarchy::SEPARATOR)
      segments[0..-2].reverse.first(2).join(", ").presence
    end

    def self.region(path) = path.split(Geo::Hierarchy::SEPARATOR).first
  end
end
