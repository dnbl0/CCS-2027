# frozen_string_literal: true

require "application_system_test_case"

# The /browse page in a real browser, on the Browse list template (2026-11-23): a section for each way in, its eight cards as the fluid
# mosaic (four lanes on a desktop, one on a phone, no tile over another), axe (WCAG 2.2 AA), no sideways scroll. The lists are given to the
# page (the cache), so it does not depend on the index.
class BrowseSectionsSystemTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    BrowseHubs.all.each do |hub|
      picture = { id: "r1", title: "A print", path: "/digital-assets/thumbs/0000_013_1_pf.jpg", width: 400, height: 300 }
      entries = (1..9).map { |number| { "label" => "#{hub.singular} #{number}", "count" => 5, "intro" => "Includes prints. Held in University Art Collection.", "image" => (picture if number <= 5) } }
      Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/#{hub.slug}"), entries.first(8), expires_in: 1.day)
    end
  end

  teardown { Rails.cache = @cache }

  def overlaps
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll('main .mosaic-flow.is-ready')].flatMap(list => {
        const boxes = [...list.children].map(li => li.getBoundingClientRect()).filter(r => r.width)
        return boxes.flatMap((a, i) => boxes.slice(i + 1).filter(b => a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1))
      }).length
    JS
  end

  test "on a desktop: no axe violations, a section for each way in, its eight cards as a mosaic of four lanes, no tile over another" do
    page.current_window.resize_to(1440, 900)
    visit "/browse"

    # one Browse (the IA fixes): the categories' sections, makers and subjects, then the other ways in
    assert_selector "main section.home-section", minimum: 9
    assert_selector ".browse-makers .mosaic-flow.is-ready article.explore-card", count: 8
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    lefts = page.evaluate_script("[...document.querySelectorAll('.browse-makers .mosaic-flow__item')].map(e => Math.round(e.getBoundingClientRect().left))")
    assert_equal 4, lefts.uniq.size, "four lanes"
    assert_equal 0, overlaps
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end

  test "on a phone: no axe violations, one lane, no sideways scroll" do
    page.current_window.resize_to(390, 844)
    visit "/browse"

    assert_selector ".browse-makers .mosaic-flow.is-ready article.explore-card", count: 8
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    lefts = page.evaluate_script("[...document.querySelectorAll('.browse-makers .mosaic-flow__item')].map(e => Math.round(e.getBoundingClientRect().left))")
    assert_equal 1, lefts.uniq.size, "one lane"
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end

  test "a section's heading leads to every value of its way in, and each card opens the value's own page" do
    visit "/browse"

    within ".browse-makers" do
      assert_selector "h2", text: "Makers"
      assert_selector "a.home-section__link[href='/browse/makers']"
      assert_selector "article.explore-card h3 a[href^='/browse/makers/']", count: 8
    end
  end
end
