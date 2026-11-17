# frozen_string_literal: true

require "application_system_test_case"

# The /browse page in a real browser: a section for each way in, two rows of four cards on a desktop, one column on a phone, axe (WCAG 2.2 AA),
# 44px targets, no sideways scroll, and alternating backgrounds. The lists are given to the page (the cache), so it does not depend on the index.
class BrowseSectionsSystemTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    BrowseHubs.all.each do |hub|
      entries = (1..9).map { |number| { "label" => "#{hub.singular} #{number}", "count" => 5, "intro" => "Includes prints. Held in University Art Collection.", "image" => nil } }
      Rails.cache.write(SuppressedRecord.cache_key("browse_cards/v3/#{hub.slug}"), entries.first(8), expires_in: 1.day)
    end
  end

  teardown { Rails.cache = @cache }

  test "on a desktop: no axe violations, eight cards in two rows of four in each section, alternating backgrounds" do
    page.current_window.resize_to(1440, 900)
    visit "/browse"

    assert_selector "main > section.ccs-section", count: 5
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    assert_selector ".browse-object-types article.explore-card", count: 8
    lefts = page.evaluate_script("[...document.querySelectorAll('.browse-object-types .discover-cards__item')].map(e => Math.round(e.getBoundingClientRect().left))")
    assert_equal 4, lefts.uniq.size
    colours = page.evaluate_script("[...document.querySelectorAll('main > section.ccs-section')].map(s => getComputedStyle(s).backgroundColor)")
    assert_equal colours.size - 1, colours.each_cons(2).count { |a, b| a != b }, "the sections' backgrounds alternate"
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end

  test "on a phone: no axe violations, one column, no sideways scroll" do
    page.current_window.resize_to(390, 844)
    visit "/browse"

    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    lefts = page.evaluate_script("[...document.querySelectorAll('.browse-places .discover-cards__item')].map(e => Math.round(e.getBoundingClientRect().left))")
    assert_equal 1, lefts.uniq.size
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end

  test "a card opens the search results with its filter applied" do
    page.current_window.resize_to(1440, 900)
    visit "/browse"
    click_link "Object type 1", match: :first

    assert_current_path(/\/catalog\?.*classification_ssim.*object\+type\+1/)
  end
end
