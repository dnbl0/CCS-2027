require "application_system_test_case"
require_relative "../support/env_override"

# Explore by time (the real index) and by place (stubbed geocoded data: the CI core has no coordinates) in a real browser: axe at
# desktop and phone width, the arrow keys on the period strip, and the opt-in map with the keyboard. No tile is fetched from the
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
        assert_selector ".timeline__link", minimum: 2
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
        assert_no_horizontal_scroll

        first(".timeline__zoom").click
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

  test "the strip opens on the period with the most records, scrolling only the strip" do
    page.driver.resize(1440, 900)
    visit "/explore/time"
    assert_selector ".timeline__link", minimum: 2

    visible = page.evaluate_script(<<~JS)
      (() => {
        const strip = document.querySelector('.timeline'), links = [...strip.querySelectorAll('.timeline__link')]
        const busiest = links.reduce((a, b) => Number(b.dataset.count) > Number(a.dataset.count) ? b : a).closest('li')
        const s = strip.getBoundingClientRect(), p = busiest.getBoundingClientRect()
        return p.left >= s.left - 1 && p.right <= s.right + 1
      })()
    JS
    assert visible, "the busiest period is in view when the page opens"
    assert_equal 0, page.evaluate_script("window.scrollX"), "only the strip scrolled, not the page"
  end

  test "the arrow keys move between periods, and a period opens the search with its years" do
    visit "/explore/time"
    links = all(".timeline__link")
    page.execute_script("document.querySelector('.timeline__link').focus()")
    page.driver.browser.keyboard.type(:right)
    assert_equal links[1].text.squish, page.evaluate_script("document.activeElement.textContent").squish
    page.driver.browser.keyboard.type(:End)
    assert_equal links.last.text.squish, page.evaluate_script("document.activeElement.textContent").squish
    page.driver.browser.keyboard.type(:left)
    assert_equal links[-2].text.squish, page.evaluate_script("document.activeElement.textContent").squish

    links[1].click
    assert_current_path(/range%5Bdate_start_isi%5D%5Bbegin%5D=/)
    assert_selector ".result-card", minimum: 1
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
