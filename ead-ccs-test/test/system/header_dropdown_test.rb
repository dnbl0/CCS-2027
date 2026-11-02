require "application_system_test_case"

# The header's dropdown panel is a block flush with the right edge under the header (as on unimelb.edu.au), not a bar across the
# whole window, and the page below the header is dimmed while it is open; clicking the dimmed page closes it.
class HeaderDropdownTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    page.current_window.resize_to(1400, 900)
  end

  test "the open Search collections panel is narrower than the window and sits against the header's right edge" do
    visit root_path
    find(".site-nav__trigger", text: "Search collections").click
    assert_selector "#site-nav-records", visible: :visible

    box = page.evaluate_script("(() => { const r = document.getElementById('site-nav-records').getBoundingClientRect(); const h = document.querySelector('.site-header').getBoundingClientRect(); return { left: r.left, right: r.right, width: r.width, top: r.top, headerBottom: h.bottom, headerRight: h.right, vw: document.documentElement.clientWidth } })()")
    assert_operator box["width"], :<, box["vw"] * 0.6, "the panel should not run the full window width"
    assert_in_delta box["headerRight"], box["right"], 1, "the panel is flush with the header's right edge"
    assert_in_delta box["headerBottom"], box["top"], 1, "the panel starts directly under the header"
  end

  test "the page below the header is dimmed while a dropdown is open, and clicking it closes the dropdown" do
    visit root_path
    dim = "(() => { const s = getComputedStyle(document.querySelector('.site-header'), '::after'); return s.content === 'none' ? null : s.backgroundColor })()"
    assert_nil page.evaluate_script(dim)

    find(".site-nav__trigger", text: "Search collections").click
    assert_selector ".site-nav__trigger[aria-expanded=true]"
    assert_equal "rgba(0, 0, 0, 0.65)", page.evaluate_script(dim)

    page.driver.click(200, 600) # on the dimmed page, away from the panel
    assert_no_selector ".site-nav__trigger[aria-expanded=true]"
    assert_nil page.evaluate_script(dim)
  end

  test "My saved items opens a panel with the visitor's own pages, and a link in it opens that page" do
    visit root_path
    find(".site-nav__trigger", text: "My saved items").click
    assert_selector "#site-nav-saved", visible: :visible
    %w[Saved\ records Your\ lists Saved\ searches Search\ history].each { |label| assert_selector "#site-nav-saved a", text: label }
    page.save_screenshot(Rails.root.join("tmp/screenshots/my_saved_items_desktop.png").to_s)

    within("#site-nav-saved") { click_link "Search history" }
    assert_current_path "/search_history"
    assert_selector "h1", text: "Search history"
  end

  test "Escape closes an open dropdown and returns focus to its trigger" do
    visit root_path
    trigger = find(".site-nav__trigger", text: "Help")
    trigger.click
    assert_selector "#site-nav-help", visible: :visible
    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector ".site-nav__trigger[aria-expanded=true]"
    assert_equal "site-nav-help", page.evaluate_script("document.activeElement.getAttribute('aria-controls')")
  end

  test "on a phone, opening a section moves focus to its Back button, and Back returns it to the trigger" do
    page.current_window.resize_to(390, 800)
    visit root_path
    find(".site-header__menu").click
    find(".site-nav__trigger", text: "Help").click
    assert_selector "#site-nav-help", visible: :visible
    assert page.evaluate_script("document.activeElement.closest('#site-nav-help') !== null")

    find("#site-nav-help .site-nav__back").click
    assert_equal "site-nav-help", page.evaluate_script("document.activeElement.getAttribute('aria-controls')")
  end
end
