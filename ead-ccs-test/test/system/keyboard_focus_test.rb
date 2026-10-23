require "application_system_test_case"

# Keyboard and screen-reader checks from the 2026-10-22 accessibility audit (WCAG 2.4.3 Focus Order, 2.4.11 Focus Not
# Obscured, 4.1.2 Name Role Value, 2.4.4 Link Purpose): the search overlay and the phone menu drawer keep Tab inside
# themselves while they cover the page, the site's custom dropdowns are named by their label and then their value, and the
# "Collections Navigator" home link keeps its name when a phone menu section is open. Names are read from Chrome's own
# accessibility tree, so they are what a screen reader is given.
class KeyboardFocusTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
  end

  def press_tab = page.driver.browser.keyboard.type(:Tab)

  # The focused element, described for failure messages, and whether it is inside the element matching `selector`
  def focus_report(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.activeElement
        const inside = !el || el === document.body || Boolean(el.closest(#{selector.to_json}))
        return { inside, what: el ? el.outerHTML.slice(0, 120) : "nothing" }
      })()
    JS
  end

  # Tabs through `presses` times and fails at the first stop outside `selector` (the page body, which Chrome focuses
  # between the last element and the browser's own controls, counts as inside)
  def assert_tab_stays_within(selector, presses: 12)
    presses.times do |n|
      press_tab
      report = focus_report(selector)
      assert report["inside"], "Tab #{n + 1} left #{selector} for #{report["what"]}"
    end
  end

  # The accessible name Chrome computes for the visible element matching `selector` (the sticky search strip holds an
  # inert copy of the search form, so the first match in the document is not always the one on screen)
  def accessible_name(selector)
    find(selector).execute_script("this.setAttribute('data-name-probe', '')")
    cdp = page.driver.browser.page
    root = cdp.command("DOM.getDocument", depth: 0)["root"]["nodeId"]
    node = cdp.command("DOM.querySelector", nodeId: root, selector: "[data-name-probe]")["nodeId"]
    page.execute_script("document.querySelector('[data-name-probe]').removeAttribute('data-name-probe')")
    tree = cdp.command("Accessibility.getPartialAXTree", nodeId: node, fetchRelatives: false)
    tree["nodes"].first.dig("name", "value").to_s.squish
  end

  test "Tab stays inside the search overlay while it is open, and Escape returns focus to the search button" do
    page.current_window.resize_to(1400, 900)
    visit search_catalog_path(q: "skull", any_assets: "1")

    find(".site-header__search-toggle").click
    assert_selector "#search-overlay.is-open"
    assert_equal "search-overlay-input", page.evaluate_script("document.activeElement.id")

    assert_tab_stays_within("#search-overlay")

    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector "#search-overlay.is-open"
    assert page.evaluate_script("document.activeElement.matches('.site-header__search-toggle')"), "focus returns to the search button"
    assert_equal 0, page.evaluate_script("document.querySelectorAll('[inert]:not(.sticky-search)').length"), "nothing is left inert after closing"
  end

  test "the overlay's Close button closes it and returns focus to the search button" do
    page.current_window.resize_to(1400, 900)
    visit root_path
    find(".site-header__search-toggle").click
    assert_selector "#search-overlay.is-open"

    find(".search-overlay__close").click
    assert_no_selector "#search-overlay.is-open"
    assert page.evaluate_script("document.activeElement.matches('.site-header__search-toggle')")
    assert_equal 0, page.evaluate_script("document.querySelectorAll('[inert]:not(.sticky-search)').length")
  end

  test "on a phone, Tab stays inside the header while the menu drawer is open, and the page is usable again once it closes" do
    page.driver.resize(390, 800)
    visit search_catalog_path(q: "skull", any_assets: "1")

    find("button.site-header__menu").click
    assert_selector "#site-nav", visible: true
    assert_tab_stays_within(".site-header", presses: 20)

    find("button.site-header__menu").click
    assert_no_selector "#site-nav", visible: true
    assert_equal 0, page.evaluate_script("document.querySelectorAll('[inert]:not(.sticky-search)').length"), "closing the drawer releases the page"
  end

  test "widening the window to desktop with the phone drawer open releases the page behind it" do
    page.driver.resize(390, 800)
    visit search_catalog_path(q: "skull", any_assets: "1")
    find("button.site-header__menu").click
    assert_operator page.evaluate_script("document.querySelectorAll('[inert]:not(.sticky-search)').length"), :>, 0

    page.driver.resize(1400, 900)
    assert_equal 0, page.evaluate_script("document.querySelectorAll('[inert]:not(.sticky-search)').length")
  end

  test "the search bar's Search in dropdown is named by its label and then its value" do
    page.current_window.resize_to(1400, 900)
    visit search_catalog_path(q: "skull", any_assets: "1")
    toggle = ".search-banner__form .ccs-select .dropdown-toggle"
    assert_selector toggle

    assert_equal "Search in All Fields", accessible_name(toggle)
  end

  test "the results-per-page button says how many results per page once, at desktop and phone widths" do
    page.current_window.resize_to(1400, 900)
    visit search_catalog_path(q: "skull", any_assets: "1")
    toggle = "#per_page-dropdown .dropdown-toggle"
    assert_equal "40 results per page", find(toggle).text.squish
    assert_equal "40 results per page", accessible_name(toggle)

    page.driver.resize(390, 800)
    visit search_catalog_path(q: "skull", any_assets: "1")
    assert_equal "40 per page", find(toggle).text.squish
    assert_equal "40 per page", accessible_name(toggle)
  end

  test "on a phone the home link stays visible with its own name when a menu section is open; the section name is shown under it as text" do
    page.driver.resize(390, 800)
    visit root_path
    find("button.site-header__menu").click
    find("button.site-nav__trigger[aria-controls=site-nav-records]").click

    home = "a.site-header__title[href='/']:not(.sticky-search *)"
    assert_selector ".site-header__section", text: "Browse records", visible: true
    assert_no_selector "a.site-header__section", visible: :all
    assert_selector home, text: "Collections Navigator", visible: true
    assert_equal "Collections Navigator", accessible_name(home)
    assert_no_selector "a[href='/']", text: "Browse records", visible: :all

    box = page.evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector(".site-header a.site-header__title").getBoundingClientRect()
        const section = document.querySelector(".site-header__section").getBoundingClientRect()
        const bar = document.querySelector(".site-header__bar").getBoundingClientRect()
        return { linkBottom: link.bottom, linkHeight: link.height, sectionTop: section.top, sectionBottom: section.bottom, barBottom: bar.bottom }
      })()
    JS
    assert_operator box["sectionTop"], :>=, box["linkBottom"] - 1, "the section name sits under the link"
    assert_operator box["sectionBottom"], :<=, box["barBottom"] + 1, "both fit in the header bar"
    assert_operator box["linkHeight"], :>=, 24, "the link keeps a usable target size"

    find("button.site-header__menu").click # Close: the drawer and its section close together
    assert_no_selector ".site-header__section", visible: true
    assert_selector home, text: "Collections Navigator", visible: true
  end
end
