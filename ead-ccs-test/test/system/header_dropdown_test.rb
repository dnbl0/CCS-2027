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
end
