require "application_system_test_case"

# The slim navy search bar fixed to the top of the window: it appears once the page's banner has scrolled away and goes
# again when the banner is back in view.
class StickySearchTest < ApplicationSystemTestCase
  setup do
    page.driver.set_cookie("country_acknowledged", "1")
  end

  def scroll_to(y) = page.execute_script("window.scrollTo(0, #{y})")

  test "the home page bar appears after the hero scrolls away and goes when it returns" do
    visit root_path

    assert_no_selector ".sticky-search.is-visible"
    scroll_to 1200
    assert_selector ".sticky-search.is-visible"
    assert_selector ".sticky-search a.site-header__title", text: "Collections Navigator"
    assert_selector ".sticky-search a.advanced_search"
    assert_selector ".sticky-search input#sticky_q"
    scroll_to 0
    assert_no_selector ".sticky-search.is-visible"
  end

  test "the bar is slim and searches the collections" do
    visit root_path
    scroll_to 1200
    assert_selector ".sticky-search.is-visible"

    height = find(".sticky-search").evaluate_script("this.getBoundingClientRect().height")
    assert_operator height, :<=, 61

    fill_in "sticky_q", with: "skull"
    find("#sticky-search-submit").click
    assert_current_path(/\/catalog\?.*q=skull/)
  end

  def rect(selector) = find(selector, visible: :all).evaluate_script("(() => { const r = this.getBoundingClientRect(); return [r.left, r.right, r.height]; })()")

  test "desktop: the title, then 48px, then the search bar and, 16px after it, Advanced Search, in the page container" do
    visit root_path
    scroll_to 1200
    assert_selector ".sticky-search.is-visible"

    title, bar, link = rect(".sticky-search__title"), rect(".sticky-search .search-banner__form"), rect(".sticky-search .advanced_search")
    inner = rect(".sticky-search__inner")
    assert_in_delta 1264, inner[1] - inner[0], 1           # --layout-container, the banner's own
    assert_in_delta inner[0] + 32, title[0], 1             # the title starts inside its 32px gutter
    assert_in_delta 48, bar[0] - title[1], 1              # --space-48 between the title and the group
    assert_in_delta 16, link[0] - bar[1], 1               # --space-16 between the bar and Advanced Search
    assert_in_delta inner[1] - 32, link[1], 1             # Advanced Search ends at the right gutter
    assert_operator bar[1] - bar[0], :>, 720              # the bar takes the rest of the width, wider than the banner's
    assert_in_delta 40, bar[2], 1
    assert_operator link[2], :>=, 44
  end

  test "the scope menu's label is centred in its button, in the strip as in the hero's bar" do
    visit root_path
    centre = lambda do |selector|
      find(selector).evaluate_script(<<~JS)
        (() => {
          const toggle = this.querySelector(".dropdown-toggle"), box = toggle.getBoundingClientRect();
          const range = document.createRange(); range.selectNodeContents(toggle);
          const text = range.getBoundingClientRect();
          return (text.top + text.height / 2) - (box.top + box.height / 2);
        })()
      JS
    end
    assert_in_delta 0, centre.call(".ccs-hero__search .ccs-select"), 1

    scroll_to 1200
    assert_selector ".sticky-search.is-visible"
    assert_in_delta 0, centre.call(".sticky-search .ccs-select"), 1
  end

  test "tablet: the bar and Advanced Search, without the title" do
    page.driver.resize(820, 1000)
    visit root_path
    scroll_to 1200
    assert_selector ".sticky-search.is-visible"

    assert_selector ".sticky-search .advanced_search", visible: :visible
    assert_no_selector ".sticky-search__title", visible: :visible
    bar, link = rect(".sticky-search .search-banner__form"), rect(".sticky-search .advanced_search")
    assert_operator bar[1], :<=, link[0]
    assert_operator link[1], :<=, 820
  ensure
    page.driver.resize(1440, 900)
  end

  test "phone: the bar alone, filling the strip" do
    page.driver.resize(390, 800)
    visit root_path
    scroll_to 1200
    assert_selector ".sticky-search.is-visible"

    assert_no_selector ".sticky-search .advanced_search", visible: :visible
    assert_no_selector ".sticky-search__title", visible: :visible
    bar = rect(".sticky-search .search-banner__form")
    assert_in_delta 358, bar[1] - bar[0], 2 # 390px less a 16px gutter each side
  ensure
    page.driver.resize(1440, 900)
  end

  test "the strip is a labelled search landmark with no axe violations while it is showing, on a page that also has the banner's search" do
    visit search_catalog_path(any_assets: "1", q: "skull", search_field: "all_fields")
    scroll_to 1500
    assert_selector ".sticky-search.is-visible"

    assert_selector ".sticky-search search[aria-label='Quick search']"
    assert_accessible
  end

  # The suggestions are Blacklight's own <auto-complete> element fetching /catalog/suggest. The test index has no suggester
  # dictionary, so the browser's fetch answers that one URL; the sticky bar's wiring is what is under test.
  def stub_suggestions
    page.execute_script(<<~JS)
      const realFetch = window.fetch.bind(window);
      window.fetch = (url, opts) => String(url).includes("/catalog/suggest")
        ? Promise.resolve(new Response('<li role="option" class="dropdown-item"><span>sculpture</span></li><li role="option" class="dropdown-item"><span>skeleton sets</span></li>', { status: 200, headers: { "Content-Type": "text/html" } }))
        : realFetch(url, opts);
    JS
  end

  test "typing in the sticky bar offers Blacklight's suggestions in its own list, and choosing one fills the box" do
    visit search_catalog_path(any_assets: "1", q: "skull", search_field: "all_fields")
    stub_suggestions
    scroll_to 1500
    assert_selector ".sticky-search.is-visible"

    find("#sticky_q").click
    find("#sticky_q").send_keys("sk")
    assert_selector "#sticky-autocomplete-popup li[role=option]", text: "sculpture", visible: :visible
    assert_no_selector "#autocomplete-popup li[role=option]", visible: :visible # the banner's own list is left alone

    find("#sticky-autocomplete-popup li[role=option]", text: "skeleton sets").click
    assert_equal "skeleton sets", find("#sticky_q").value
  end
end
