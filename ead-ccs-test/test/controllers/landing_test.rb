require "test_helper"

class LandingTest < ActionDispatch::IntegrationTest
  test "the front page is the home page" do
    get "/"

    assert_response :success
    assert_select "body.page-home h1", "Collections Navigator"
    assert_select ".ccs-hero__search search form"
    assert_select ".ccs-hero__search a.advanced_search[href=?]", "/catalog/advanced"
    assert_select ".home-card__title a", count: 6
    assert_select ".home-about__statement", count: 1
    assert_select ".home-card__text a[href=?]", "https://museumsandcollections.unimelb.edu.au/collections"
    assert_select ".ccs-section--help, .ccs-section--faq", count: 0
  end

  test "the Collections Navigator card searches all five collections" do
    get "/"

    assert_select ".home-card__text", /search all five collections/
    assert_select "a.home-textbutton[href=?]", "/catalog?search_field=all_fields", text: /University museums and collections/
    assert_select ".home-card__title a[href=?]", "/catalog?search_field=all_fields", text: "Collections Navigator"
  end

  test "a bare search page goes to the home page with the hero search" do
    get "/catalog"

    assert_redirected_to "/"
  end

  test "every page carries the sticky strip: the title, the same search bar and Advanced Search, hidden until the banner has scrolled away" do
    [ "/", "/help", "/about" ].each do |path|
      get path

      assert_select ".sticky-search[data-controller=sticky-search][inert][aria-hidden=true]", count: 1
      assert_select ".sticky-search a.site-header__title[href=?]", "/", text: "Collections Navigator"
      assert_select ".sticky-search form.search-query-form[action=?][method=get]", "/catalog"
      assert_select ".sticky-search select[name=search_field]#sticky_search_field"
      assert_select ".sticky-search input[name=q]#sticky_q"
      assert_select ".sticky-search button#sticky-search-submit"
      assert_select ".sticky-search auto-complete[src=?][for=sticky-autocomplete-popup]", "/catalog/suggest"
      assert_select ".sticky-search ul#sticky-autocomplete-popup[role=listbox]"
      assert_select ".sticky-search a.advanced_search[href^=?]", "/catalog/advanced"
    end
  end

  test "the sticky bar keeps the current query" do
    get "/catalog", params: { q: "skull", any_assets: "1", search_field: "all_fields" }

    assert_select ".sticky-search input#sticky_q[value=skull]"
  end

  test "no id is used twice on the page with the sticky strip, with the search banner" do
    get "/catalog", params: { q: "skull", any_assets: "1", search_field: "all_fields" }

    ids = css_select("[id]").map { |node| node["id"] }
    assert_equal [], ids.tally.select { |_, n| n > 1 }.keys
  end
end
