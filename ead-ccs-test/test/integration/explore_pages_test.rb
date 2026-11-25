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

  test "the timeline: a strip of the centuries, each the same width and named, the periods as tiles opening their own pages, the eras folded" do
    visit("/browse/time?view=timeline") { seed("timeline/all", timeline) }

    assert_response :success
    assert_select "title", /\ATimeline — Time — /
    assert_select "h1", "Time" # the one Browse template: its title, then the views as tabs, the timeline the third
    assert_select "nav.places-views a.places-views__link", count: 3
    assert_select "nav.places-views a.places-views__link[aria-current=page][href$='view=timeline']", "Timeline"
    assert_select "nav.places-views a.places-views__link[href='/browse/time']", "All"
    assert_select "turbo-frame#time-explorer[target=_top][data-turbo-action=advance] nav.explore-strip--time[aria-label=Centuries]" do
      items = css_select("a.explore-strip__period")
      assert_equal [ "Earlier (Before 3000 BCE): 2 records", "1900s (1900–1999): 1,200 records" ], items.map { |item| item["aria-label"] }
      assert_equal %w[Earlier 1900s], items.map { |item| item.text.squish }, "the name shown is the start of the name read out"
      # a century swaps in place (the link names the frame); the earliest period, not a century, opens its records
      assert_select "a.explore-strip__period[href='/browse/time?century=1900'][data-turbo-frame=time-explorer]"
      assert_select "a.explore-strip__period[href*='range%5Bdate_start_isi%5D%5Bend%5D=-3001']:not([data-turbo-frame])"
      assert_select "a[aria-current]", 0, "no century chosen yet"
      assert_select ".explore-strip__bar[aria-hidden=true]", 2
    end
    assert_select ".explore-strip__note", /most are from 1900–1999 \(1,200 records\)/
    # the periods, earliest first: a century from 1000 opens its own page (its decades are there), an earlier one its records in the search
    assert_select ".time-explorer__periods a[href='/browse/periods/1900-1999']", text: /\A1900–1999/
    assert_select ".time-explorer__periods a[href*='range%5Bdate_start_isi%5D%5Bend%5D=-3001']", text: /\ABefore 3000 BCE/
    assert_select ".time-explorer__periods .mosaic-flow img[alt='']", 1 # the period with a picture is a tile; the other is a link after
    assert_select ".time-explorer__periods", text: /1900–1999\s+1,200 records/
    assert_select "details.time-explorer__eras summary", "Eras as catalogued (1)"
    assert_select "details.time-explorer__eras a[href*='f%5Bdate_era_ssim%5D%5B%5D=20th+century']", text: /20th century/
  end

  test "a chosen century: marked in the strip, its records as a wall of squares, its decades, and the way back; a century not in the strip is no choice" do
    wall = [ PictureWall::Record.new(id: "emu-1", title: "A print", src: "https://example.org/1.jpg", tint: "#97b2be") ]
    visit("/browse/time?century=1900") do
      seed("timeline/all", timeline)
      seed("timeline/1900", timeline(century: 1900))
      Rails.cache.write(SuppressedRecord.cache_key("picture_wall/v2/time/1900"), wall.map { |record| record.to_h.transform_keys(&:to_s) }, expires_in: 1.hour)
    end
    assert_select "title", /\A1900–1999 — Timeline — Time — /
    assert_select "h1", "Time"
    assert_select "a.explore-strip__period[aria-current=page][data-explore-strip-target=chosen]", "1900s"
    assert_select "section.picture-wall" do
      assert_select "h2#picture-wall-heading", "1900–1999"
      assert_select ".picture-wall__count", "1,200 records"
      assert_select ".picture-wall__links a[href='/browse/periods/1900-1999']", "See all 1,200"
      assert_select "a.picture-wall__link[href='/catalog/emu-1'] .picture-wall__title", "A print"
    end
    assert_select "h2", "Decades of 1900–1999"
    assert_select ".time-explorer__periods a[href='/browse/periods/1920-1929']", text: /\A1920–1929/
    assert_select "a[href$='view=timeline'][data-turbo-frame=time-explorer]", text: "All centuries"
    assert_select "details.time-explorer__eras", 0

    visit("/browse/time?century=1950") { seed("timeline/all", timeline) }
    assert_select "h2", "Centuries"
    visit("/browse/time?century=1200") { seed("timeline/all", timeline) }
    assert_select "section.picture-wall", 0
    assert_select "h2", "Centuries"
  end

  test "the places page: picture cards beside an opt-in map, region chips, a name box, and every place in lists" do
    melbourne = P::Marker.new(path: "Oceania|Australia|Victoria|Melbourne", lat: -37.81, lon: 144.96, count: 10)
    paris = P::Marker.new(path: "Europe|France|Île-de-France|Paris", lat: 48.85, lon: 2.35, count: 4)
    country = P::Node.new(path: "Oceania|Australia", count: 12, children: [ melbourne ])
    english = P::Node.new(path: "English", count: 3, children: []) # not a region: a stray value of the hierarchy, offered as no chip
    result = P::Result.new(markers: [ melbourne, paris ], regions: [ P::Node.new(path: "Oceania", count: 12, children: [ country ]), english ], plain_regions: [], top_places: [])
    cards = [ { "label" => "Melbourne", "count" => 8, "total" => 9, "image" => { "id" => "r1", "title" => "A tram", "path" => "https://unimelbourne.widen.net/content/a/jpeg/a.jpeg?w=1000&u=x", "width" => 800, "height" => 600 } } ]
    visit("/browse/places?view=map") do
      seed("places", result)
      Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/places/map/v1"), cards, expires_in: 1.day)
    end

    assert_response :success
    assert_select "h1", "Places"
    assert_select "nav.places-views a.places-views__link[aria-current=page][href$='view=map']", "Map"
    assert_select ".place-explorer__chip", 2 # Everywhere and Oceania
    assert_select ".place-explorer__chip[aria-pressed='true']", "Everywhere"
    assert_select ".place-explorer__chip[data-region='English']", 0
    assert_select "input[type='search']#place-explorer-find"
    # the card: its own page, where it is and the pin's number of records
    assert_select "li[data-key='0'] .place-tile" do
      assert_select "h3 a.place-tile__link[href^='/browse/places/']", "Melbourne"
      assert_select ".place-tile__where", "Victoria, Australia"
      assert_select ".place-tile__count", "10 records"
      assert_select ".place-tile__media img[alt=''][src*='w=600']"
    end
    assert_select "svg.place-explorer__dots[aria-hidden='true']" # the map's preview, drawn from the page's own data
    assert_select "button.place-explorer__switch", "Show map"
    assert_select ".place-explorer__status[role='status']", "1 place"
    # the map: nothing asked of the tile server until the visitor presses Show the map
    assert_select ".place-explorer__consent button", "Show the map"
    assert_select ".place-explorer__stage[hidden] #place-map"
    assert_select "[data-place-explorer-attribution-value*='openstreetmap.org/copyright']"
    assert_select "[data-place-explorer-tiles-value='https://tile.openstreetmap.org/{z}/{x}/{y}.png']"
    markers = JSON.parse(css_select("[data-place-explorer-markers-value]").first["data-place-explorer-markers-value"])
    assert_equal [ "Melbourne", "Paris" ], markers.map { |marker| marker["label"] }
    assert_equal [ true, false ], markers.map { |marker| marker["card"] }
    assert_equal [ "Oceania", "Europe" ], markers.map { |marker| marker["region"] }
    assert_match %r{\A/browse/places/}, markers.first["href"]
    assert_includes markers.last["href"], "place_hierarchy_ssim"
    assert_no_match(/tile\.openstreetmap\.org[^"]*"\s*(src|href)=/, response.body)
    assert_select "link[href*='leaflet']"
    # every region, country and place, as lists (the same job without the map)
    assert_select "details.place-explorer__all summary", "Every place, by region and country (2)"
    assert_select "h3 a[href*='f%5Bplace_hierarchy_ssim%5D%5B%5D=Oceania']", "Oceania"
    assert_select "a.browse__link[href*='Oceania%7CAustralia']", text: /Australia\s+12 records/
    assert_select "details details summary", "Places in Australia (1)"
  end

  test "before any place is located: no map, the regions and the commonest places" do
    result = P::Result.new(markers: [], regions: [], plain_regions: [ P::Entry.new("region_ssim", "Oceania", 5) ],
                           top_places: [ P::Entry.new("production_place_ssim", "Melbourne", 3) ])
    visit("/browse/places?view=map") { seed("places", result) }

    assert_select "button", text: "Show the map", count: 0
    assert_select "link[href*='leaflet']", 0
    assert_select "a[href*='f%5Bregion_ssim%5D%5B%5D=Oceania']", text: /Oceania/
    assert_select "a[href*='f%5Bproduction_place_ssim%5D%5B%5D=Melbourne']", text: /Melbourne/
  end

  test "Solr down and nothing kept: a plain 503 with a way to the search" do
    with_seeded_menu_cache do
      with_solr_down do
        get "/browse/time", params: { view: "timeline" }
        assert_response :service_unavailable
        get "/browse/places", params: { view: "map" }
        assert_response :service_unavailable
      end
    end
    assert_select "a", text: "search all records"
  end

  test "the policy names the tile host, and the privacy page says when it is contacted" do
    get "/privacy"
    assert_includes response.headers["Content-Security-Policy-Report-Only"], "img-src 'self' data: https: https://tile.openstreetmap.org"
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
