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
    test "a record page loads its Similar records, with no axe violations, at #{name}" do
      page.current_window.resize_to(width, 900)
      visit "/catalog/emu-10247"
      page.execute_script("document.getElementById('similar-records').scrollIntoView()")

      assert_selector "#similar-records h2", text: "Similar records"
      assert_selector "#similar-records article.result-card", minimum: 2
      page.execute_script("window.scrollTo(0, 0)") # the sticky search bar that appears on scrolling has a known landmark finding of its own
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end

    test "/discover has no axe violations and does not scroll sideways at #{name}" do
      page.current_window.resize_to(width, 900)
      visit "/discover"

      assert_selector "h1", text: "Discover", count: 1
      assert_selector "h2", text: "Pick of the day"
      assert_selector ".discover-section--featured article", minimum: 2
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page scrolls sideways"
    end

    test "the home page fills its Featured and trending section when it scrolls into view, with no axe violations, at #{name}" do
      page.current_window.resize_to(width, 900)
      visit "/"
      page.execute_script("document.getElementById('home-discover-heading').scrollIntoView()")

      assert_selector "turbo-frame#home-discover[complete] .discover-section--featured article", minimum: 2
      assert_link "See all featured and trending records", href: "/discover"
      page.execute_script("window.scrollTo(0, 0)")
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end
  end

  test "a record with a withheld asset has no Similar records section" do
    visit "/catalog/#{first_id('licence_type_ssim:"ICIP Rights"')}"

    assert_selector "h1", visible: :all
    assert_no_selector "#similar-records"
  end
end
