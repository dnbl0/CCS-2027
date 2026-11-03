require "application_system_test_case"

# While a modal is open the page behind it must not scroll (wheel or keyboard), must not shift when the scrollbar goes, and
# comes back at the same scroll position when the modal closes. Every modal-like surface shares one mechanism
# (components/modal.css + app/javascript/modal_lock.js): <dialog>s lock through :has(dialog[open]), the search overlay and the
# mobile filter drawer through html.has-open-modal. Runs against the Solr core at SOLR_URL (see application_system_test_case.rb).
class ModalScrollLockTest < ApplicationSystemTestCase
  setup do
    # The Acknowledgement of Country would sit over every page; it has its own test below
    page.driver.set_cookie("country_acknowledged", "1")
  end

  def root_overflow = page.evaluate_script("getComputedStyle(document.documentElement).overflowY")
  def root_gutter = page.evaluate_script("getComputedStyle(document.documentElement).scrollbarGutter")
  def scroll_y = page.evaluate_script("Math.round(window.scrollY)")

  def scroll_page_to(top)
    page.execute_script("window.scrollTo({ top: #{top}, behavior: 'instant' })")
    assert_equal top, scroll_y
  end

  # A real wheel event over the page behind, then the keys that scroll a page when focus is on the body
  def push_the_page
    page.execute_script("document.activeElement && document.activeElement.blur()")
    page.driver.browser.page.command("Input.dispatchMouseEvent", type: "mouseWheel", x: 8, y: 360, deltaX: 0, deltaY: 900)
    sleep 0.3
    keyboard = page.driver.browser.keyboard
    %i[page_down space down end].each { |key| keyboard.type(key) }
    sleep 0.3
  end

  def assert_locked_and_unmoved(start_y)
    assert_equal "hidden", root_overflow, "the root does not scroll while the modal is open"
    # (the page does not shift when the scrollbar goes: the gutter stays reserved; checked with real scrollbars in tests/modal-scroll-lock.test.js,
    # as the headless browser here hides its scrollbars)
    assert_equal "stable", root_gutter, "the scrollbar's gutter stays reserved"
    push_the_page
    assert_equal start_y, scroll_y, "wheel, PageDown, Space, arrows and End do not scroll the page behind"
  end

  def assert_unlocked_at(start_y)
    assert_not_equal "hidden", root_overflow, "the page scrolls again"
    assert_equal start_y, scroll_y, "scrolling is restored at exactly the same position"
  end

  test "the Acknowledgement of Country locks the page while it is open and releases it on Continue" do
    page.driver.clear_cookies
    visit root_path
    assert_selector "#country-acknowledgement[open]"
    assert_equal "hidden", root_overflow
    assert_equal "stable", root_gutter
    push_the_page
    assert_equal 0, scroll_y

    click_on "Continue"
    assert_no_selector "#country-acknowledgement[open]"
    assert_not_equal "hidden", root_overflow
  end

  test "the Acknowledgement of Country is the Gen 3 modal: navy blanket, square white panel, a Close button" do
    page.driver.clear_cookies
    visit root_path
    assert_selector "#country-acknowledgement[open]"

    assert_equal "rgba(0, 11, 52, 0.8)", page.evaluate_script("getComputedStyle(document.querySelector('#country-acknowledgement'), '::backdrop').backgroundColor")
    panel = find("#country-acknowledgement .modal-content")
    assert_equal "0px", panel.evaluate_script("getComputedStyle(this).borderTopLeftRadius")
    assert_equal "24px", panel.evaluate_script("getComputedStyle(this).paddingTop")
    close = find("#country-acknowledgement .modal-close")
    assert_equal "Close", close.text
    assert_equal "fixed", page.evaluate_script("getComputedStyle(document.querySelector('#country-acknowledgement')).position")

    close.click
    assert_no_selector "#country-acknowledgement[open]"
  end

  # The record page has other dialog buttons (Cite this record, Share and embed); this one opens the leaving-site dialog
  LEAVING_SITE_OPENER = "button[data-action='dialog#open']:not(.cite__button):not(.share__button)".freeze

  test "the leaving-site dialog locks the page, and Escape, the Close button and the backdrop each release it where it was" do
    visit search_catalog_path(any_assets: "1", q: "skull")
    first(".result-card .document-title-heading a").click
    assert_selector LEAVING_SITE_OPENER

    [ -> { page.driver.browser.keyboard.type(:Escape) }, -> { find("dialog[open] .modal-close").click }, -> { page.driver.browser.mouse.click(x: 6, y: 6) } ].each do |close|
      scroll_page_to(200)
      find(LEAVING_SITE_OPENER).trigger("click")
      assert_selector "dialog[open]"
      assert_locked_and_unmoved(200)
      close.call
      assert_no_selector "dialog[open]"
      assert_unlocked_at(200)
    end
  end

  test "the search overlay locks the page and releases it where it was" do
    visit search_catalog_path(any_assets: "1", q: "skull")
    scroll_page_to(700)

    page.execute_script("document.querySelector('.site-header__search-toggle').click()")
    assert_selector "#search-overlay.is-open"
    assert_selector "html.has-open-modal"
    assert_locked_and_unmoved(700)

    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector "#search-overlay.is-open"
    assert_no_selector "html.has-open-modal"
    assert_unlocked_at(700)
  end

  test "the mobile filter drawer locks the page and the scrim, Escape and Close release it where it was" do
    page.driver.resize(390, 800)
    visit search_catalog_path(any_assets: "1", q: "skull")

    [ -> { page.driver.browser.keyboard.type(:Escape) }, -> { find(".filter-drawer__close").click }, -> { page.execute_script("document.querySelector('.filter-backdrop').click()") } ].each do |close|
      scroll_page_to(400)
      page.execute_script("document.querySelector('.filters-toggle').click()")
      assert_selector "#sidebar.is-open"
      assert_selector "html.has-open-modal"
      assert_locked_and_unmoved(400)
      close.call
      assert_no_selector "#sidebar.is-open"
      assert_no_selector "html.has-open-modal"
      assert_unlocked_at(400)
    end
  ensure
    page.driver.resize(1440, 900)
  end

  test "leaving a page with the search overlay open does not leave the next page locked" do
    visit search_catalog_path(any_assets: "1", q: "skull")
    page.execute_script("document.querySelector('.site-header__search-toggle').click()")
    assert_selector "html.has-open-modal"

    # Turbo caches the page it leaves: the lock and any open dialog are released first
    page.execute_script("document.dispatchEvent(new Event('turbo:before-cache'))")
    assert_no_selector "html.has-open-modal"
  end
end
