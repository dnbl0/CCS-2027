require "application_system_test_case"

# The look every page shares: buttons and form controls use the body font; in-content links are one style; page section
# headings are one size (the design consistency pass).
class StyleConsistencyTest < ApplicationSystemTestCase
  PAGES = %w[/ /browse /help /about /accessibility /privacy /selection /bookmarks /lists/new /catalog/advanced].freeze

  setup do
    page.driver.remove_cookie(CookieNotice::COOKIE.to_s)
    page.driver.set_cookie("country_acknowledged", "1")
  end

  def computed(selector, property)
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(#{selector.to_json})).filter(function (e) { return e.getClientRects().length > 0 })
        .map(function (e) { return getComputedStyle(e)[#{property.to_json}] })
    JS
  end

  test "every button and form control uses the body font, not the browser's" do
    PAGES.each do |path|
      visit path
      # The one exception is the "all / any" menu in the Advanced search heading: the design sets it in the heading's own serif
      fonts = computed("button, .btn, input:not([type=hidden]), select:not(.input-small), textarea", "fontFamily")

      assert_not_empty fonts, path
      assert fonts.all? { |font| font.include?("Source Sans 3") }, "#{path}: #{fonts.uniq.inspect}"
    end
  end

  test "an in-content link is link blue and underlined on every page" do
    %w[/help /about /accessibility /privacy].each do |path|
      visit path
      links = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("main p a:not(.jump-nav__link), main li a:not(.jump-nav__link), main dd a")).filter(function (e) { return e.getClientRects().length > 0 })
          .map(function (e) { var s = getComputedStyle(e); return [s.color, s.textDecorationLine] })
      JS

      assert_not_empty links, path
      assert_equal [ [ "rgb(0, 63, 139)", "underline" ] ], links.uniq, path
    end
  end

  test "the cookie notice is a white strip in the body font" do
    visit "/help"

    assert_equal "rgb(255, 255, 255)", page.evaluate_script("getComputedStyle(document.querySelector('.cookie-notice')).backgroundColor")
    assert_includes page.evaluate_script("getComputedStyle(document.querySelector('.cookie-notice')).fontFamily"), "Source Sans 3"
  end

  test "a page's section headings are the same size on the Help, About and Privacy pages" do
    sizes = %w[/help /about /privacy].map do |path|
      visit path
      page.evaluate_script("getComputedStyle(document.querySelector('.help-section__heading')).fontSize")
    end

    assert_equal 1, sizes.uniq.size, sizes.inspect
  end
end
