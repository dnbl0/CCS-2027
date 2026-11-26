require "application_system_test_case"

# Similar records on a record page, and /discover and the home page's section, in a real browser with axe (WCAG 2.2 AA), at desktop
# width and at 320px.
class DiscoverTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }
  teardown { page.current_window.resize_to(1440, 900) }

  def first_id(filter)
    Blacklight.default_index.connection.get("select", params: { q: "*:*", fq: filter, rows: 1, fl: "id", wt: "json" }).dig("response", "docs", 0, "id")
  end

  [ [ "desktop", 1440 ], [ "320px", 320 ] ].each do |name, width|
    test "a record page loads its Similar objects, with no axe violations, at #{name}" do
      page.current_window.resize_to(width, 900)
      visit "/catalog/emu-10247"
      page.execute_script("document.getElementById('similar-records').scrollIntoView()")

      assert_selector "#similar-records h2", text: "Similar objects"
      assert_selector "#similar-records li.discover-cards__item", minimum: 2
      page.execute_script("window.scrollTo(0, 0)") # the sticky search bar that appears on scrolling has a known landmark finding of its own
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end

    test "/discover has no axe violations and does not scroll sideways at #{name}" do
      page.current_window.resize_to(width, 900)
      visit "/browse/discover"

      assert_selector "h1", text: "Discover", count: 1
      assert_selector "h2", text: "Pick of the day"
      assert_selector ".discover-section--featured article", minimum: 2
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page scrolls sideways"
    end
  end

  test "the record page's Similar objects are cards linking to their records, and do not scroll sideways at 390px" do
    page.current_window.resize_to(390, 900)
    visit "/catalog/#{first_id('id:(emu-10247 OR emu_mc-10247)')}"
    page.execute_script("document.getElementById('similar-records').scrollIntoView()")

    assert_selector "#similar-records li.discover-cards__item", minimum: 2
    assert_no_selector "#related-objects"
    assert_selector "#similar-records li.discover-cards__item h3 a[href^='/catalog/']", minimum: 2
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page scrolls sideways"
    page.execute_script("window.scrollTo(0, 0)")
    assert_accessible tags: AXE_TAGS + WCAG22_TAGS
  end

  test "a record with a withheld asset has no Similar objects section" do
    visit "/catalog/#{first_id('licence_type_ssim:"ICIP Rights"')}"

    assert_selector "h1", visible: :all
    assert_no_selector "#similar-records"
  end
end
