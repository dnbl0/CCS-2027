require "test_helper"
require_relative "../support/canned_search"
require_relative "../support/outages"

# Explore by time and by place (ExploreController), from cached answers: no Solr in this job (the system test reads a real core)
class ExplorePagesTest < ActionDispatch::IntegrationTest
  include CannedSearch
  include Outages

  T = Explore::Timeline
  P = Explore::Places

  def timeline(century: nil)
    periods = century ? [ T::Period.new(first: 1920, last: 1929, count: 5, images: []) ] :
      [ T::Period.new(first: nil, last: -3001, count: 2, images: []),
        T::Period.new(first: 1900, last: 1999, count: 1200, images: [ T::Image.new(id: "r1", title: "Print", src: "https://example.org/r1.jpg") ]) ]
    T::Result.new(periods: periods, eras: century ? [] : [ T::Era.new("20th century", 900) ], century: century)
  end

  def seed(key, value) = Rails.cache.write(SuppressedRecord.cache_key("explore/v1/#{key}"), value, expires_in: 1.hour)

  def visit(path)
    with_seeded_menu_cache do
      yield if block_given?
      get path
    end
  end

  test "the timeline is a list of periods that open the search with the year range, with decades and eras" do
    visit("/explore/time") { seed("timeline/all", timeline) }

    assert_response :success
    assert_select "h1", "Explore by time"
    assert_select "ol.timeline li", 2
    assert_select "a.timeline__link[href*='range%5Bdate_start_isi%5D%5Bbegin%5D=1900'][href*='range%5Bdate_start_isi%5D%5Bend%5D=1999']", text: /1900–1999\s+1,200 records/
    assert_select "a.timeline__link[href*='range%5Bdate_start_isi%5D%5Bend%5D=-3001']", text: /Before 3000 BCE/
    assert_select "a.timeline__link img[alt='']", 1
    assert_select "a.timeline__zoom[href='/explore/time?century=1900']", text: /Decades of 1900–1999/
    assert_select ".explore-chips a[href*='f%5Bdate_era_ssim%5D%5B%5D=20th+century']", text: /20th century/
  end

  test "a century's decades, with the way back; a century that is not one shows every century" do
    visit("/explore/time?century=1900") { seed("timeline/1900", timeline(century: 1900)) }
    assert_select "h2", "Decades of 1900–1999"
    assert_select "a[href='/explore/time']", text: "All centuries"
    assert_select "a.timeline__zoom", 0

    visit("/explore/time?century=1950") { seed("timeline/all", timeline) }
    assert_select "h2", "Centuries"
  end

  test "the places page: an opt-in map with the same places in lists of regions and countries" do
    marker = P::Marker.new(path: "Oceania|Australia|Victoria|Melbourne", lat: -37.81, lon: 144.96, count: 10)
    country = P::Node.new(path: "Oceania|Australia", count: 12, children: [ marker ])
    result = P::Result.new(markers: [ marker ], regions: [ P::Node.new(path: "Oceania", count: 12, children: [ country ]) ], plain_regions: [], top_places: [])
    visit("/explore/places") { seed("places", result) }

    assert_response :success
    assert_select "button[aria-expanded='false'][aria-controls='place-map']", "Show the map"
    assert_select "#place-map[hidden]"
    assert_select "[data-place-map-attribution-value*='openstreetmap.org/copyright']"
    assert_select "[data-place-map-tiles-value='https://tile.openstreetmap.org/{z}/{x}/{y}.png']"
    assert_select ".explore-map__credit a[href='https://www.openstreetmap.org/copyright']"
    assert_select "h3 a[href*='f%5Bplace_hierarchy_ssim%5D%5B%5D=Oceania']", "Oceania"
    assert_select "a.browse__link[href*='Oceania%7CAustralia']", text: /Australia\s+12 records/
    assert_select "details summary", "Places in Australia (1)"
    assert_select "details a[href*='Oceania%7CAustralia%7CVictoria%7CMelbourne']", text: /Melbourne/
    assert_no_match(/tile\.openstreetmap\.org[^"]*"\s*(src|href)=/, response.body)
    assert_select "link[href*='leaflet']"
  end

  test "before any place is located: no map, the regions and the commonest places" do
    result = P::Result.new(markers: [], regions: [], plain_regions: [ P::Entry.new("region_ssim", "Oceania", 5) ],
                           top_places: [ P::Entry.new("production_place_ssim", "Melbourne", 3) ])
    visit("/explore/places") { seed("places", result) }

    assert_select "button", text: "Show the map", count: 0
    assert_select "link[href*='leaflet']", 0
    assert_select "a[href*='f%5Bregion_ssim%5D%5B%5D=Oceania']", text: /Oceania/
    assert_select "a[href*='f%5Bproduction_place_ssim%5D%5B%5D=Melbourne']", text: /Melbourne/
  end

  test "Solr down and nothing kept: a plain 503 with a way to the search" do
    with_seeded_menu_cache do
      with_solr_down do
        get "/explore/time"
        assert_response :service_unavailable
        get "/explore/places"
        assert_response :service_unavailable
      end
    end
    assert_select "a", text: "search all records"
  end

  test "the policy names the tile host, and the privacy page says when it is contacted" do
    get "/privacy"
    assert_includes response.headers["Content-Security-Policy-Report-Only"], "img-src 'self' data: blob: https: https://tile.openstreetmap.org"
    assert_select "#map-tiles", text: /OpenStreetMap/
  end

  test "the Place filter is a tree of the hierarchy with its last level as the label" do
    facets = { "place_hierarchy_ssim" => [ "Oceania", 12, "Oceania|Australia", 12, "Oceania|Australia|Victoria", 10, "Europe", 4 ] }
    answer = canned_response([]).tap { |body| body["facet_counts"]["facet_fields"] = facets }
    with_seeded_menu_cache do
      with_canned_search(answer) do
        get "/catalog", params: { q: "", any_assets: "1", f: { place_hierarchy_ssim: [ "Oceania|Australia" ] } }
      end
    end

    assert_response :success
    sidebar = css_select(".place-hierarchy").first
    assert sidebar, "the Place filter is shown"
    assert_select ".place-hierarchy > li", 2
    assert_select ".place-hierarchy > li:first-child details[open] summary", "Within Oceania"
    assert_select ".place-hierarchy .facet-label", text: "Victoria"
    assert_select ".place-hierarchy .selected", minimum: 1
    assert_select ".place-hierarchy .selected", text: /Australia/, minimum: 1
  end

  # Speed: a results page drew every state and town (1,384 values, 412 on a "photograph" search), which took most of its time.
  # Regions and their countries are drawn; the levels under a country only once it (or something in it) is chosen.
  test "the Place filter draws regions and countries, and the levels under a country only once it is chosen" do
    facets = { "place_hierarchy_ssim" => [ "Oceania", 12, "Oceania|Australia", 12, "Oceania|Australia|Victoria", 10,
                                           "Oceania|Australia|Victoria|Ballarat", 3, "Europe", 4, "Europe|France", 4 ] }
    answer = canned_response([]).tap { |body| body["facet_counts"]["facet_fields"] = facets }
    with_seeded_menu_cache do
      with_canned_search(answer) { get "/catalog", params: { q: "", any_assets: "1" } }
    end

    assert_response :success
    assert_select ".place-hierarchy .facet-label", text: "Australia"
    assert_select ".place-hierarchy .facet-label", text: "France"
    assert_select ".place-hierarchy .facet-label", text: "Victoria", count: 0
    assert_select ".place-hierarchy .facet-label", text: "Ballarat", count: 0

    with_seeded_menu_cache do
      with_canned_search(answer) do
        get "/catalog", params: { q: "", any_assets: "1", f: { place_hierarchy_ssim: [ "Oceania|Australia|Victoria" ] } }
      end
    end
    assert_select ".place-hierarchy .facet-label", text: "Ballarat"
    assert_select ".place-hierarchy .facet-label", text: "France"
  end
end
