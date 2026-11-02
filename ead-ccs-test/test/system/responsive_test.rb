require "application_system_test_case"

# Responsive layout (CCS-63, BR-16.07; WCAG 2.2 1.4.10 Reflow, 2.5.8 Target size): the key pages in a 320px and a 390px window do not
# scroll sideways, the buttons and links in the main content are at least 24px high and wide, and a narrow page has no axe violations.
# The fixes are in components/responsive.css; docs/responsive-audit-2026-11.md lists what was found.
class ResponsiveTest < ApplicationSystemTestCase
  WIDTHS = [ 320, 390 ].freeze

  PAGES = {
    "home" => "/",
    "results as a list" => "/catalog?any_assets=1&q=skull&view=list",
    "results as a mosaic" => "/catalog?any_assets=1&q=skull&view=masonry",
    "a record" => "/catalog/emu-10133",
    "advanced search" => "/catalog/advanced",
    "help" => "/help",
    "about" => "/about",
    "the access request form" => "/access_requests/new?document_id=vernon-MHM00394",
    "the new record page" => "/branded-stock/emu-9044"
  }.freeze

  # Controls in the main content that are visible and not a link inside a sentence (the target size rule exempts those)
  SMALL_TARGETS = <<~JS.freeze
    [...document.querySelectorAll("main a[href], main button, main input:not([type=hidden]), main select, main summary")].filter((e) => {
      const r = e.getBoundingClientRect(), style = getComputedStyle(e)
      if (r.width === 0 || r.height === 0 || style.visibility === "hidden" || e.closest("[hidden], .visually-hidden")) return false
      const sentence = e.tagName === "A" && style.display === "inline" && e.parentElement.textContent.trim() !== e.textContent.trim()
      return !sentence && (r.width < 24 || r.height < 24)
    }).map((e) => e.tagName.toLowerCase() + "." + e.className + " " + Math.round(e.getBoundingClientRect().width) + "x" + Math.round(e.getBoundingClientRect().height))
  JS

  setup { page.driver.set_cookie("country_acknowledged", "1") }

  teardown { page.current_window.resize_to(1400, 900) }

  PAGES.each do |name, path|
    WIDTHS.each do |width|
      test "#{name} at #{width}px does not scroll sideways, and its buttons and links are at least 24px" do
        page.current_window.resize_to(width, 844)
        visit path
        assert_selector "main"

        scroll, client = page.evaluate_script("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
        assert_operator scroll, :<=, client, "#{path} is #{scroll}px wide in a #{client}px window"
        assert_empty page.evaluate_script(SMALL_TARGETS), "targets under 24px on #{path}"
      end
    end
  end

  test "the phone menu opens in a 320px window without scrolling sideways, its links 44px tall" do
    page.current_window.resize_to(320, 844)
    visit root_path
    find(".site-header__menu").click
    assert_selector ".site-nav.is-open"

    scroll, client = page.evaluate_script("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
    assert_operator scroll, :<=, client
    heights = page.evaluate_script("[...document.querySelectorAll('.site-nav.is-open a, .site-nav.is-open button')].filter((e) => e.getBoundingClientRect().width > 0).map((e) => e.getBoundingClientRect().height)")
    assert heights.all? { |height| height >= 44 }, "a menu link is under 44px: #{heights}"
  end

  test "large text does not make a results page scroll sideways at 320px" do
    page.current_window.resize_to(320, 844)
    visit search_catalog_path(any_assets: "1", q: "skull", view: "list")
    page.execute_script("document.documentElement.style.fontSize = '200%'")

    scroll, client = page.evaluate_script("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
    assert_operator scroll, :<=, client, "the page is #{scroll}px wide in a #{client}px window with text at 200%"
  end

  test "a results page, a record and the access request form have no axe violations at 320px" do
    page.current_window.resize_to(320, 844)
    [ "/catalog?any_assets=1&q=skull&view=list", "/catalog/emu-10133", "/access_requests/new?document_id=vernon-MHM00394" ].each do |path|
      visit path
      assert_selector "main"
      assert_accessible
    end
  end
end
