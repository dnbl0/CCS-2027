require "application_system_test_case"
require_relative "../support/debias_helper"

# De-bias notices in a real browser with axe (WCAG 2.2 AA and best practice), at desktop width and at 320 px. The term list is a test
# double: an ordinary word from the record with made-up explanations. The real list is the collections team's.
class DebiasNoticesSystemTest < ApplicationSystemTestCase
  include DebiasHelper

  RECORD = "/catalog/emu-406126" # title "Percy Grainger"

  setup { page.driver.set_cookie("country_acknowledged", "1") }

  def sideways_scroll = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")

  def flagged_record
    with_debias_terms(debias_entry("grainger", severity: "caution", explanation: "Made-up reason.", alternative: "made-up alternative")) { yield }
  end

  test "a record page with a notice has no axe violations, and the mark is a labelled element, not colour alone" do
    flagged_record do
      visit RECORD

      assert_selector "aside.record-debias h2", text: "This record contains language that may be offensive or outdated"
      assert_selector "mark.debias-flag .visually-hidden", text: "flagged term:", visible: :all
      assert_equal "underline", page.evaluate_script("getComputedStyle(document.querySelector('mark.debias-flag')).textDecorationLine")
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end
  end

  test "the notice's links are reachable by keyboard-visible targets of at least 24 px" do
    flagged_record do
      visit RECORD

      sizes = page.evaluate_script("Array.from(document.querySelectorAll('.record-debias a')).map(function (a) { var r = a.getBoundingClientRect(); return [r.width, r.height] })")
      assert_operator sizes.size, :>=, 2
      sizes.each { |width, height| assert_operator [ width, height ].max, :>=, 24 } # inline links in a sentence are exempt from 2.5.8; none is tiny
    end
  end

  test "the page the notice links to has no axe violations, one h1, and the link goes there" do
    flagged_record do
      visit RECORD
      click_link "about the language in our records"

      assert_selector "h1", text: "About the language in our records", count: 1
      assert_selector "main#main-content"
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end
  end

  test "at 320 px the record page with a notice and the language page do not scroll sideways and have no axe violations" do
    page.current_window.resize_to(320, 800)
    flagged_record do
      visit RECORD
      assert_selector "aside.record-debias"
      assert_operator sideways_scroll, :<=, 0
      assert_accessible tags: AXE_TAGS + WCAG22_TAGS
    end

    visit "/language-in-our-records"
    assert_selector "h1"
    assert_operator sideways_scroll, :<=, 0
    assert_accessible tags: AXE_TAGS + WCAG22_TAGS
  end

  test "the notice does not move the page once it has loaded" do
    flagged_record do
      visit RECORD
      top = page.evaluate_script("document.querySelector('.record-specs').getBoundingClientRect().top")
      sleep 0.5
      assert_equal top, page.evaluate_script("document.querySelector('.record-specs').getBoundingClientRect().top")
    end
  end
end
