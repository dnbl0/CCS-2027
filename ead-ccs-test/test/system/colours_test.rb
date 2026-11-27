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

  test "the colour page at a desktop and a phone width: every colour named (no counts), accessible, no sideways scroll" do
    [ [ 1400, 900 ], [ 390, 844 ], [ 320, 700 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      visit "/explore/colours"

      assert_selector "h1", text: "Explore by colour"
      assert_selector "a.colours__link", count: 12
      assert_selector "a.colours__link", exact_text: "White" # the name only: no count
      assert_not sideways_scroll?, "no sideways scroll at #{width}px"
      assert_accessible
    end
    click_link "Red"
    assert_current_path(/colour_ssim/)
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
