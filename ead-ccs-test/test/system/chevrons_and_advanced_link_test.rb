require "application_system_test_case"

# The dropdown chevrons turn upside down while their menu is open, and the "Advanced Search" link under the search bar is
# styled like the footer links (a blue arrow on the left, a bold white label, no button box).
class ChevronsAndAdvancedLinkTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
  end

  FLIPPED = "matrix(-1, 0, 0, -1, 0, 0)".freeze

  def settle = sleep(0.5) # the chevrons animate

  test "the header's Search collections chevron points up while its menu is open" do
    visit root_path
    trigger = find(".site-nav__trigger", text: "Search collections")
    turn = "getComputedStyle(this.querySelector('img')).transform"
    settle
    assert_equal "none", trigger.evaluate_script(turn)
    trigger.click
    assert_selector ".site-nav__trigger[aria-expanded=true]", text: "Search collections"
    settle
    assert_equal FLIPPED, trigger.evaluate_script(turn)
    trigger.click
    settle
    assert_equal "none", trigger.evaluate_script(turn)
  end

  test "the search bar's dropdown chevron points up while its menu is open" do
    visit search_catalog_path(any_assets: "1", q: "skull")
    toggle = find(".search-banner .ccs-select > .dropdown-toggle")
    turn = "getComputedStyle(this, '::after').transform"
    settle
    assert_equal "none", toggle.evaluate_script(turn)
    toggle.click
    assert_selector ".search-banner .ccs-select > .dropdown-toggle.show"
    settle
    assert_equal FLIPPED, toggle.evaluate_script(turn)
  end

  test "the Advanced Search link is a footer-style link: blue arrow, bold white label, no button box" do
    [ root_path, search_catalog_path(any_assets: "1", q: "skull") ].each do |path|
      visit path
      link = first("a.advanced_search")
      assert_equal "Advanced Search", link.text, path
      look = link.evaluate_script(<<~JS)
        (function (a) {
          var c = getComputedStyle(a), b = getComputedStyle(a, '::before');
          return { bg: c.backgroundColor, color: c.color, weight: Number(c.fontWeight), border: c.borderTopWidth,
                   arrow: [b.width, b.height], arrowImage: /^url\\(/.test(b.backgroundImage) };
        })(this)
      JS
      assert_equal "rgba(0, 0, 0, 0)", look["bg"], path
      assert_equal "0px", look["border"], path
      assert_equal "rgb(255, 255, 255)", look["color"], path
      assert_operator look["weight"], :>=, 600, path
      assert_equal [ "24px", "24px" ], look["arrow"], path
      assert look["arrowImage"], "#{path}: the arrow is drawn before the label"

      # The footer links are the reference: same type, spacing and height, read live from the page's own footer
      measure = <<~JS
        (function (a) {
          var c = getComputedStyle(a), r = a.getBoundingClientRect();
          return { size: c.fontSize, weight: c.fontWeight, line: c.lineHeight, spacing: c.letterSpacing, gap: c.columnGap,
                   underline: c.textDecorationLine, minHeight: c.minHeight, height: r.height };
        })(this)
      JS
      footer = first(".site-footer a.arrow-link--inverse", minimum: 1)
      assert_equal footer.evaluate_script(measure), link.evaluate_script(measure), "#{path}: matches the footer links"
    end
  end
end
