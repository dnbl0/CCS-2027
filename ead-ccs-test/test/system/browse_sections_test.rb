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
      picture = { id: "r1", title: "A print", path: "/digital-assets/thumbs/0000_013_1_pf.jpg", width: 400, height: 300 }
      entries = (1..9).map { |number| { "label" => "#{hub.singular} #{number}", "count" => 5, "intro" => "Includes prints. Held in University Art Collection.", "image" => (picture if number <= 5) } }
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
    lefts = page.evaluate_script("[...document.querySelectorAll('.browse-object-types .card-layout__item')].map(e => Math.round(e.getBoundingClientRect().left))")
    assert_equal 4, lefts.uniq.size
    colours = page.evaluate_script("[...document.querySelectorAll('main > section.ccs-section')].map(s => getComputedStyle(s).backgroundColor)")
    assert_equal colours.size - 1, colours.each_cons(2).count { |a, b| a != b }, "the sections' backgrounds alternate"
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end

  test "each section has its own layout, and the picture is shown whole on its tile under a navy scrim (card_tiles.css)" do
    page.current_window.resize_to(1440, 900)
    visit "/browse"

    { "object-types" => "bento", "places" => "rail", "periods" => "strip", "makers" => "grid", "subjects" => "wall" }.each do |slug, layout|
      assert_selector ".browse-#{slug} .card-layout--#{layout}"
    end
    widths = page.evaluate_script("[...document.querySelectorAll('.browse-object-types .card-layout__item')].map(e => Math.round(e.getBoundingClientRect().width))")
    assert_operator widths.first, :>, widths[1] * 1.8, "the bento's first card is about twice as wide as a small one"
    assert_equal "contain", page.evaluate_script("getComputedStyle(document.querySelector('.card-layout .result-card__media img')).objectFit") # shown whole, never cropped
    assert_match(/linear-gradient/, page.evaluate_script("getComputedStyle(document.querySelector('.card-layout .explore-card:not(.explore-card--text) .result-card__content')).backgroundImage"),
                 "the name sits on a scrim, so its contrast does not depend on the picture")
    assert_selector ".browse-subjects .card-layout__item--panel a", text: "See all subjects"
  end

  test "the rail's buttons scroll the row and show only where there is more" do
    page.current_window.resize_to(1440, 900)
    visit "/browse"

    assert_no_selector ".browse-places .card-rail__button--previous", visible: :visible
    assert_selector ".browse-places .card-rail__button--next", visible: :visible
    find(".browse-places .card-rail__button--next").click
    assert_selector ".browse-places .card-rail__button--previous", visible: :visible
    assert_operator page.evaluate_script("document.querySelector('.browse-places .card-layout__list').scrollLeft"), :>, 0
    assert_equal "0", page.evaluate_script("document.querySelector('.browse-places .card-layout__list').getAttribute('tabindex')")
  end

  test "the rail hands the keyboard focus to its row when the button under it is hidden" do
    page.current_window.resize_to(1440, 900)
    visit "/browse"

    20.times do
      break if page.evaluate_script("document.querySelector('.browse-places .card-rail__button--next').hidden")

      page.execute_script("document.querySelector('.browse-places .card-rail__button--next').focus(); document.querySelector('.browse-places .card-rail__button--next').click()")
      wait_until_stable("the places row's scroll") { page.evaluate_script("document.querySelector('.browse-places .card-layout__list').scrollLeft") }
    end
    assert page.evaluate_script("document.querySelector('.browse-places .card-rail__button--next').hidden"), "the row scrolled to its end"
    assert page.evaluate_script("document.activeElement === document.querySelector('.browse-places .card-layout__list')"), "the focus is on the row, not lost"
  end

  test "a narrow cell leaves out the description" do
    page.current_window.resize_to(320, 700)
    visit "/browse"

    assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelectorAll('.browse-object-types .card-layout__item')[1].querySelector('.explore-card__intro')).display")
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end

  test "the strip widens the card that is focused and the first card at rest" do
    page.current_window.resize_to(1440, 900)
    visit "/browse"

    widths = lambda { page.evaluate_script("[...document.querySelectorAll('.browse-periods .card-layout__item')].map(e => Math.round(e.getBoundingClientRect().width))") }
    at_rest = widths.call
    assert_operator at_rest.first, :>, at_rest[1] * 2
    page.execute_script("document.querySelectorAll('.browse-periods .explore-card__link')[3].focus()")
    wait_for_animations
    focused = widths.call
    assert_operator focused[3], :>, focused[1] * 2
    assert_operator focused.first, :<, at_rest.first
  end

  test "on a phone: no axe violations, one column, no sideways scroll" do
    page.current_window.resize_to(390, 844)
    visit "/browse"

    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    assert_equal 1, page.evaluate_script("new Set([...document.querySelectorAll('.browse-places .card-layout__item')].map(e => Math.round(e.getBoundingClientRect().top))).size"), "the rail is one row"
    assert_selector ".browse-periods .card-layout__item", count: 8
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end

  test "a card opens the search results with its filter applied" do
    page.current_window.resize_to(1440, 900)
    visit "/browse"
    click_link "Object type 1", match: :first

    assert_current_path(/\/catalog\?.*classification_ssim.*object\+type\+1/)
  end
end
