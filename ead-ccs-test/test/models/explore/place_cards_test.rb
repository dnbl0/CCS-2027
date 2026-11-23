require "test_helper"

class Explore::PlaceCardsTest < ActiveSupport::TestCase
  P = Explore::Places
  Card = Browse::Cards::Card

  def card(label) = Card.new(label: label, count: 1, query: {}, image: nil, intro: nil, path: "/browse/places/#{label.downcase}")

  test "each card is joined by name to its pin: the pin's key, number, region and the line of where it is" do
    victoria_au = P::Marker.new(path: "Oceania|Australia|Victoria", lat: -36.6, lon: 144.7, count: 40)
    victoria_ca = P::Marker.new(path: "North America|Canada|British Columbia|Victoria", lat: 48.4, lon: -123.4, count: 3)
    australia = P::Marker.new(path: "Oceania|Australia", lat: -24.8, lon: 134.8, count: 90)
    places = P::Result.new(markers: [ australia, victoria_au, victoria_ca ], regions: [], plain_regions: [], top_places: [])

    items = Explore::PlaceCards.for(places, [ card("Victoria"), card("Australia"), card("Atlantis") ])

    assert_equal [ [ 1, "Victoria", "Australia, Oceania", 40, "Oceania" ], [ 0, "Australia", "Oceania", 90, "Oceania" ] ],
                 items.map { |item| [ item.key, item.label, item.where, item.count, item.region ] }, "the busier Victoria; no pin, no card"
    assert_equal "/browse/places/victoria", items.first.path
  end

  test "no map, no cards" do
    assert_empty Explore::PlaceCards.for(P::Result.new(markers: [], regions: [], plain_regions: [], top_places: []), [ card("Melbourne") ])
  end
end
