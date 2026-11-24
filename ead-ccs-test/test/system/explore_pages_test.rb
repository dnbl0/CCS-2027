require "application_system_test_case"
require_relative "../support/env_override"

# Explore by time (the real index) and by place (stubbed geocoded data: the CI core has no coordinates) in a real browser: axe at
# desktop and phone width, the periods' tiles in time order, and the opt-in map with the keyboard. No tile is fetched from the
# internet: MAP_TILE_URL points at a closed local port.
class ExplorePagesSystemTest < ApplicationSystemTestCase
  include EnvOverride

  WIDTHS = { "desktop" => [ 1440, 900 ], "390px" => [ 390, 844 ] }.freeze

  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    needs_solr
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    melbourne = Explore::Places::Marker.new(path: "Oceania|Australia|Victoria|Melbourne", lat: -37.81, lon: 144.96, count: 1391)
    paris = Explore::Places::Marker.new(path: "Europe|France|Île-de-France|Paris", lat: 48.85, lon: 2.35, count: 12)
    regions = [ Explore::Places::Node.new(path: "Oceania", count: 1391, children: [ Explore::Places::Node.new(path: "Oceania|Australia", count: 1391, children: [ melbourne ]) ]),
                Explore::Places::Node.new(path: "Europe", count: 12, children: [ Explore::Places::Node.new(path: "Europe|France", count: 12, children: [ paris ]) ]) ]
    Rails.cache.write(SuppressedRecord.cache_key("explore/v1/places"),
                      Explore::Places::Result.new(markers: [ melbourne, paris ], regions: regions, plain_regions: [], top_places: []), expires_in: 1.hour)
    # Melbourne has a card (its own page and picture); Paris is only a pin, listed by name under the cards
    Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/places/map/v1"),
                      [ { "label" => "Melbourne", "count" => 1391, "image" => { "id" => "r1", "title" => "A tram", "path" => "/favicon.ico", "width" => 800, "height" => 600 } } ], expires_in: 1.hour)
    page.execute_script("try { localStorage.clear() } catch (e) {}") rescue nil
  end

  teardown { Rails.cache = @cache }

  WIDTHS.each do |name, size|
    test "both pages have no axe violations at #{name}" do
      page.driver.resize(*size)
      with_env("MAP_TILE_URL" => "http://127.0.0.1:1/{z}/{x}/{y}.png") do
        visit "/explore/time"
        assert_selector ".time-explorer__periods a", minimum: 2
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
        assert_no_horizontal_scroll

        visit "/explore/time?century=1900"
        assert_selector "h2", text: /Decades of/
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)

        visit "/explore/places"
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS) # the cards, and the map's preview before it is loaded
        click_button "Show map" if name == "390px" # a phone shows the list first
        click_button "Show the map"
        assert_selector ".explore-map__pin", minimum: 1
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
        assert_no_horizontal_scroll if name == "390px"
      end
    end
  end

  test "the periods read in time order as picture tiles that do not overlap, and a century opens its own page" do
    page.driver.resize(1440, 900)
    visit "/explore/time"
    assert_selector ".time-explorer__periods .mosaic-flow.is-ready li", minimum: 2

    tiles = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.time-explorer__periods .mosaic-flow > li')].map(li => {
        const r = li.getBoundingClientRect()
        return { name: li.querySelector('h3').textContent.trim(), left: r.left, top: r.top, right: r.right, bottom: r.bottom }
      })
    JS
    overlaps = tiles.combination(2).select { |a, b| a["left"] < b["right"] - 1 && b["left"] < a["right"] - 1 && a["top"] < b["bottom"] - 1 && b["top"] < a["bottom"] - 1 }
    assert_empty overlaps.map { |pair| pair.map { |tile| tile["name"] } }, "tiles overlap"
    # in time order: each tile starts no higher than the one before it in its lane, and the first row runs left to right
    first_row = tiles.select { |tile| (tile["top"] - tiles.first["top"]).abs < 2 }
    assert_equal first_row.sort_by { |tile| tile["left"] }.map { |tile| tile["name"] }, first_row.map { |tile| tile["name"] }

    century = all(".time-explorer__periods .explore-card__link[href^='/browse/periods/']").first
    assert century, "a century from 1000 has its own page"
    century.click
    assert_selector "main.place-page h1"
  end

  test "choosing a century in the strip swaps in its wall in place: the address, the title and focus follow, and the strip scrolls to it" do
    page.driver.resize(1440, 900)
    visit "/explore/time"
    century = find("a.explore-strip__period[href='/explore/time?century=1900']")
    century.click
    assert_selector "h2#picture-wall-heading", text: "1900–1999"
    assert_selector "turbo-frame#time-explorer[complete]:not([aria-busy])", visible: :all
    assert_no_selector "html[aria-busy]", visible: :all
    assert_equal "/explore/time?century=1900", page.evaluate_script("location.pathname + location.search")
    assert_match(/\A1900–1999 — Explore by time/, page.evaluate_script("document.title"))
    assert_equal "1900s", page.evaluate_script("document.activeElement.textContent.trim()"), "focus stays on the chosen century"
    assert_selector "a.explore-strip__period[aria-current=page]", text: "1900s"
    assert_selector ".picture-wall__link", minimum: 1
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)

    click_link "All centuries"
    assert_selector "h2", text: "Centuries"
    assert_equal "/explore/time", page.evaluate_script("location.pathname + location.search")
  end

  test "the map loads only when asked, is remembered, and a place is reached with the keyboard" do
    with_env("MAP_TILE_URL" => "http://127.0.0.1:1/{z}/{x}/{y}.png") do
      visit "/explore/places"
      page.execute_script("localStorage.removeItem('ccs:place-map')")
      visit "/explore/places"
      assert_equal false, page.evaluate_script("!!document.querySelector('.leaflet-container')")
      click_button "Show the map"
      assert_selector ".leaflet-container"
      assert_equal "shown", page.evaluate_script("localStorage.getItem('ccs:place-map')")
      assert_selector ".explore-map__pin[role='button'][aria-label='Melbourne: 1,391 records']"
      page.execute_script("document.querySelector(\".explore-map__pin[aria-label^='Melbourne']\").focus()")
      page.driver.browser.keyboard.type(:enter)
      assert_selector ".leaflet-popup-content a", text: "Explore Melbourne"
      assert_equal "Explore Melbourne", page.evaluate_script("document.activeElement.textContent")
      assert_match %r{/browse/places/}, find(".leaflet-popup-content a")[:href]
      page.driver.browser.keyboard.type(:Escape)
      assert_no_selector ".leaflet-popup"
      assert_equal "Melbourne: 1,391 records", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
      assert_selector ".leaflet-control-attribution a[href='https://www.openstreetmap.org/copyright']"

      visit "/explore/places" # remembered: the map is back without asking
      assert_selector ".leaflet-container"
      click_button "Hide the map"
      assert_no_selector ".leaflet-container"
      assert_nil page.evaluate_script("localStorage.getItem('ccs:place-map')")
      assert_equal "Show the map", page.evaluate_script("document.activeElement.textContent.trim()")
    end
  end

  test "the chips and the name box narrow the cards; a card marks its pin; the places with no card are listed by name" do
    page.driver.resize(1440, 900)
    with_env("MAP_TILE_URL" => "http://127.0.0.1:1/{z}/{x}/{y}.png") do
      visit "/explore/places"
      assert_selector ".place-tile", count: 1
      assert_selector ".place-explorer__more-link", text: "Paris"

      click_button "Europe"
      assert_selector ".place-explorer__chip[aria-pressed='true']", text: "Europe"
      assert_no_selector ".place-tile"
      assert_selector ".place-explorer__empty"
      assert_selector ".place-explorer__status", text: "0 places in Europe"

      click_button "Everywhere"
      fill_in "Find a place", with: "victoria"
      assert_selector ".place-tile", text: "Melbourne" # "Victoria, Australia"
      assert_no_selector ".place-explorer__more-link", text: "Paris"
      fill_in "Find a place", with: ""

      click_button "Show the map"
      assert_selector ".explore-map__pin", minimum: 1
      find(".place-tile").hover
      assert_selector ".explore-map__pin.is-marked[aria-label^='Melbourne']"
      page.execute_script("localStorage.removeItem('ccs:place-map')")
    end
  end

  def assert_no_horizontal_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "the page scrolls sideways"
  end
end
