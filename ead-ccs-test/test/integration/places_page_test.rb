require "test_helper"

# The Places page (browse/places), after Google Arts & Culture's Places: "All", a wall of pictured places, and "A–Z", every place by letter
class PlacesPageTest < ActionDispatch::IntegrationTest
  def seed_places(values) = Rails.cache.write("browse_hubs/v1/places", values, expires_in: 1.day)

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  test "All is the default: tabs for All and A–Z, the filter, a wall of places with pictures and their full counts, and the way to every place" do
    wall = [ { "label" => "Australia", "count" => 532, "image" => { "id" => "emu-1", "title" => "A tree", "path" => "https://unimelbourne.widen.net/content/a/jpeg/a.jpeg?w=1000&u=x", "width" => nil, "height" => nil } } ]
    Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/places/wall/v2"), wall, expires_in: 1.day)
    seed_places([ [ "Australia", 8058 ], [ "Japan", 193 ] ])

    get "/browse/places", params: { view: "all" } # the plain address is the places page with the map (ExplorePagesTest)

    assert_response :success
    assert_select "h1", "Places"
    assert_select "nav.places-views a[aria-current=page]", "All"
    assert_select "nav.places-views a[href=?]", "/browse/places?view=az", text: "A–Z"
    assert_select "form[role=search] input[name=filter]"
    assert_select "ul.mosaic-flow[data-controller=mosaic][data-mosaic-lanes-value='6'] li article.explore-card--tile" do
      assert_select "img[alt=''][src*='w=600']" # a smaller rendition of the DAM picture
      assert_select "h3 a[href^='/browse/places/australia-']", "Australia" # the name under the picture, opening the place's own page
      assert_select ".explore-card__intro", "8,058 records" # every record, as the A–Z list counts them, not only the pictured ones
    end
    assert_select "turbo-frame#places-results"
    assert_select "form[data-turbo-frame=places-results] input#filter[data-action='input->places-search#type']"
    assert_select "a[href=?]", "/browse/places?view=az", text: /See every place, A–Z \(2\)/
  end

  test "A–Z: the letters across the top and the list of every place" do
    seed_places([ [ "Australia", 8058 ], [ "Japan", 193 ] ])
    get "/browse/places", params: { view: "az" }

    assert_response :success
    assert_select "nav.places-views a[aria-current=page]", "A–Z"
    assert_select "nav.places-letters a[aria-current=page]", "Most records"
    assert_select "nav.places-letters a[href=?]", "/browse/places?letter=A", text: "A"
    assert_equal [ "Australia 8,058 records", "Japan 193 records" ], css_select("a.places-list__link").map { |a| a.text.squish }
    assert_select "ul.places-wall", count: 0
  end

  test "a region narrows the list; the regions are continents, from each place's country" do
    seed_places([ [ "Carlton", 13 ], [ "Paris", 321 ], [ "Kyoto", 9 ] ])
    PlaceGeocode.create!(place: "Carlton", normalised: "carlton", country_code: "au", region: "Victoria")
    PlaceGeocode.create!(place: "Paris", normalised: "paris", country_code: "fr", region: "English")
    PlaceGeocode.create!(place: "Kyoto", normalised: "kyoto", country_code: "jp")

    get "/browse/places", params: { view: "az", region: "Europe" }

    assert_equal [ "All regions", "Asia 1", "Europe 1", "Oceania 1" ], css_select("nav.places-regions a").map { |a| a.text.squish }.sort
    assert_select "nav.places-regions a[aria-current=true]", text: /Europe/
    assert_equal [ "Paris 321 records" ], css_select("a.places-list__link").map { |a| a.text.squish }
    assert_select "h2", "Places in Europe"
  end
end
