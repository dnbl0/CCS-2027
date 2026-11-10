require "application_system_test_case"
require_relative "../support/cookie_notice_helper"

# CCS-471: the cookie notice in a real browser, with axe and the keyboard. A first-time visitor has no cookies at all.
class CookieNoticeSystemTest < ApplicationSystemTestCase
  include CookieNoticeHelper

  NOTICE = "section.cookie-notice".freeze

  setup do
    page.driver.remove_cookie(CookieNotice::COOKIE.to_s)
    page.driver.set_cookie("country_acknowledged", "1")
  end

  test "a first-time visitor sees the notice, with no axe violations (WCAG 2.2 AA and best practice)" do
    visit "/help"

    assert_selector NOTICE
    assert_selector "#{NOTICE} h2", text: "Cookies on this site"
    assert_accessible tags: AXE_TAGS + WCAG22_TAGS
  end

  test "the privacy page's cookie list, with the notice above it, has no axe violations" do
    visit "/privacy"

    assert_selector NOTICE
    assert_selector "#cookies code", text: "_ccs_session"
    assert_accessible tags: AXE_TAGS + WCAG22_TAGS
  end

  def layout_shift_of(path)
    visit path
    page.evaluate_async_script(<<~JS)
      var done = arguments[arguments.length - 1], total = 0
      new PerformanceObserver(function (list) { list.getEntries().forEach(function (e) { if (!e.hadRecentInput) total += e.value }) }).observe({ type: "layout-shift", buffered: true })
      setTimeout(function () { done(total) }, 700)
    JS
  end

  test "the notice adds no layout shift: the page shifts no more with it than without it" do
    with_notice = layout_shift_of("/help")
    assert_selector NOTICE
    page.driver.set_cookie(CookieNotice::COOKIE.to_s, CookieNotice.value("acknowledged"))
    without_notice = layout_shift_of("/help")
    assert_no_selector NOTICE

    assert_operator with_notice, :<=, without_notice + 0.005
  end

  test "it does not take focus or trap it: the first Tab goes to the skip link, and the notice's button is reached by Tab" do
    visit "/help"

    assert_not page.evaluate_script("document.querySelector('#{NOTICE}').contains(document.activeElement)")
    assert_not page.evaluate_script("!!document.querySelector('dialog[open]')")
    page.driver.browser.keyboard.type(:tab)
    assert_equal "skip-link", page.evaluate_script("document.activeElement.className").split.first
    page.driver.browser.keyboard.type(:tab) # the notice's link to the cookie list
    page.driver.browser.keyboard.type(:tab) # its button
    assert_equal "OK", page.evaluate_script("document.activeElement.textContent").strip
  end

  test "OK with the keyboard removes the notice, sends focus to the main content and the notice stays gone on the next page" do
    visit "/help"
    find("#{NOTICE} button", text: "OK").send_keys(:enter)

    assert_no_selector NOTICE
    assert_equal "MAIN", page.evaluate_script("document.activeElement.tagName")
    assert_equal "1.acknowledged", page.driver.cookies[CookieNotice::COOKIE.to_s].value

    visit "/about"
    assert_no_selector NOTICE
  end

  test "the Escape key does nothing to it and it never covers the page: it is above the header in the flow" do
    visit "/help"
    page.driver.browser.keyboard.type(:escape)
    assert_selector NOTICE
    assert_equal "static", page.evaluate_script("getComputedStyle(document.querySelector('#{NOTICE}')).position")
  end

  test "it reads at 320 CSS pixels wide with no sideways scrolling" do
    page.driver.resize(320, 700)
    visit "/help"

    assert_selector NOTICE
    assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
  ensure
    page.driver.resize(1440, 900)
  end

  test "on the home page it sits with the Acknowledgement of Country without hiding it" do
    needs_solr
    page.driver.remove_cookie("country_acknowledged")
    visit "/"

    assert_selector "#country-acknowledgement[open]"
    click_on "Continue"
    assert_selector NOTICE
  end

  test "the cookie notice is not on an embed page" do
    needs_solr
    id = Blacklight.default_index.connection.get("select", params: { q: "*:*", fq: "has_digital_asset_ssi:with", rows: 1, fl: "id", wt: "json" }).dig("response", "docs", 0, "id")
    visit "/embed/records/#{id}"

    assert_no_selector NOTICE
  end
end
