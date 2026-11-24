require "application_system_test_case"

# Explore by colour and Looks similar in a real browser, at a desktop and a phone width: axe (WCAG 2.2 AA), no sideways scroll,
# every colour named in text. The colours are given to the page (the core built in CI has none); Looks similar reads real records.
class ColoursSystemTest < ApplicationSystemTestCase
  RECORDS = %w[emu-400198 emu-400205 emu-400236].freeze

  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    @fetch = ColourCounts.method(:fetch)
    counts = Colour::Palette::NAMES.each_with_index.map { |name, index| ColourCounts::Entry.new(name: name, count: (index + 1) * 7) }
    ColourCounts.define_singleton_method(:fetch) { counts }
  end

  teardown do
    fetch = @fetch
    ColourCounts.define_singleton_method(:fetch) { fetch.call }
    page.current_window.resize_to(1400, 900)
  end

  def sideways_scroll? = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

  test "the colour page at a desktop and a phone width: every colour named and counted, accessible, no sideways scroll" do
    [ [ 1400, 900 ], [ 390, 844 ], [ 320, 700 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit "/explore/colours"

      assert_selector "h1", text: "Explore by colour"
      assert_selector "nav.explore-strip a.explore-strip__swatch", count: 12
      assert_selector "main a[href*='colour=']:not([aria-hidden]):not(.explore-strip__swatch)", count: 12
      assert_text(/White\s+84 records/)
      assert_not sideways_scroll?, "no sideways scroll at #{width}px"
      assert_accessible
    end
    # choosing a colour swaps the wall in place (a Turbo frame) and the address follows
    page.current_window.resize_to(1400, 900)
    visit "/explore/colours"
    find("a.explore-strip__swatch.colours__swatch--teal").click
    assert_selector "h2#picture-wall-heading", text: "Teal"
    assert_selector "a.explore-strip__swatch.colours__swatch--teal[aria-current=page]"
    assert_current_path "/explore/colours?colour=teal"
    assert_match(/\ATeal — Explore by colour/, page.evaluate_script("document.title"), "the tab's title follows the colour")
    assert page.evaluate_script("document.activeElement.matches('.colours__swatch--teal')"), "focus stays on the chosen swatch"
    # Turbo marks the frame and the page busy until the new wall is in and the visit is recorded: axe waits for both
    assert_selector "turbo-frame#colour-explorer[complete]:not([aria-busy])", visible: :all
    assert_no_selector "html[aria-busy]", visible: :all
    assert_accessible
    page.current_window.resize_to(390, 844)
    visit "/explore/colours?colour=white"
    assert_not sideways_scroll?
    assert_operator page.evaluate_script("document.querySelector('.explore-strip__list').scrollLeft"), :>, 0, "the chosen colour scrolled into the strip's middle"
  end

  test "Looks similar loads after More like this, with the record page's cards, accessible at a phone width" do
    needs_solr
    ColourNeighbour.create!(record_id: RECORDS[0], neighbour_ids: RECORDS.drop(1), computed_at: Time.current)
    page.current_window.resize_to(390, 844)
    visit "/catalog/#{RECORDS[0]}"
    page.execute_script("document.getElementById('looks-similar').scrollIntoView()")

    within("#looks-similar") do
      assert_selector "h2", text: "Looks similar"
      assert_selector ".object-cards__item", count: 2
    end
    assert_not sideways_scroll?
    assert_accessible
  end
end
