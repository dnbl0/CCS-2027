require "application_system_test_case"

# The record and results aids in a real browser with axe (WCAG 2.2 AA), at desktop width and at 390px: the labelled rows under a
# record, its values as links, the one-tap filters above the results, the empty page's help and the categorised suggestions.
class SearchAidsTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }
  teardown { page.current_window.resize_to(1440, 900) }

  SHOTS = Rails.root.join("tmp/screenshots/search_aids")

  def shot(name)
    FileUtils.mkdir_p(SHOTS)
    page.save_screenshot(SHOTS.join("#{name}.png").to_s, full: true)
  end

  def no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page scrolls sideways"
  end

  [ [ "desktop", 1440 ], [ "390px", 390 ] ].each do |name, width|
    test "a record page's labelled rows load under Similar objects, with no axe violations, at #{name}" do
      page.current_window.resize_to(width, 900)
      visit "/catalog/emu-10247"
      page.execute_script("document.getElementById('similar-type').scrollIntoView()")

      assert_selector "#similar-type h2", text: "More of this type"
      assert_selector "#similar-type li.discover-cards__item h3 a[href^='/catalog/']", minimum: 1
      assert_selector ".record-details__list a[href*='object_type_ssim']"
      no_sideways_scroll
      shot("record-#{name}")
      page.execute_script("window.scrollTo(0, 0)")
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end

    test "results show one-tap filters that narrow the search, with no axe violations, at #{name}" do
      page.current_window.resize_to(width, 900)
      visit "/catalog?q=portrait&search_field=all_fields&any_assets=1"

      assert_selector "nav.quick-filters h2", text: "Narrow these results"
      count = all(".quick-filters__list a").size
      assert_operator count, :>=, 2
      assert_operator count, :<=, 8
      no_sideways_scroll
      shot("results-#{name}")
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS

      first(".quick-filters__list a").click
      assert_selector ".applied-filter", minimum: 1
    end

    test "an empty page offers related categories, with no axe violations, at #{name}" do
      page.current_window.resize_to(width, 900)
      visit "/catalog?q=skull&search_field=all_fields&f%5Bhas_digital_asset%5D%5B%5D=with"

      assert_selector ".results-empty__related a", minimum: 1
      assert_no_selector ".quick-filters"
      no_sideways_scroll
      shot("empty-#{name}")
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end
  end

  test "suggestions say what they are, and the keyboard reaches and opens one" do
    visit "/catalog?q=portrait&search_field=all_fields&any_assets=1"
    input = find("#q", match: :first)
    input.set("")
    input.send_keys("grain")

    assert_selector "[role=listbox] a[role=option] .search-suggestion__kind", text: "Creator"
    shot("suggest-desktop")
    input.send_keys(:down)
    assert_equal "true", find("[role=listbox] [role=option][aria-selected=true]")["aria-selected"]
    assert_equal find("[role=listbox] [role=option][aria-selected=true]")[:id], input["aria-activedescendant"]
    input.send_keys(:enter)

    assert_selector ".applied-filter", minimum: 1
  end
end
