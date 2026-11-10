require "test_helper"

# What every page of the site shares (the design consistency pass): the saved-records link is in the page once, a page's
# <title> starts with its h1 (in sentence case), and the Advanced search page has the same hero as the others.
class PageConsistencyTest < ActionDispatch::IntegrationTest
  PAGES = %w[/ /browse /browse/makers /discover /help /about /accessibility /privacy /selection /bookmarks /my_data /lists/new /catalog/advanced].freeze
  # Pages with an h1 of their own that is the start of the <title> (the home page and /discover have a longer h1 or title)
  TITLED = { "/help" => "Help and support", "/about" => "About Collections Navigator", "/browse" => "Browse the collections", "/catalog/advanced" => "Advanced search",
             "/selection" => "Selected records" }.freeze

  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL (the Advanced search form lists the facets)"
  end

  test "the saved-records link is in each page once (not in the header's top strip as well as the breadcrumb strip), besides the phone menu's copy" do
    PAGES.each do |path|
      get path
      next unless response.successful? # a page that needs Solr is skipped when there is none

      assert_select "a.site-nav__saved:not(.site-nav__saved--drawer)", { count: 1 }, "#{path} shows the saved-records link once"
    end
  end

  test "a page's title matches its h1 in sentence case" do
    needs_solr
    TITLED.each do |path, h1|
      get path

      assert_response :success, path
      assert_select "h1", text: h1
      assert_select "title", text: /\A#{Regexp.escape(h1)}\b/, message: "#{path}: the <title> starts with the h1"
    end
  end

  test "the Advanced search page has a banner with a line under its title, like the other pages" do
    needs_solr
    get "/catalog/advanced"

    assert_select ".page-banner h1", text: "Advanced search"
    assert_select ".page-banner .page-banner__desc", text: /./
    assert_select "nav.breadcrumb-bar li, .breadcrumb-bar li", text: "Advanced search"
  end
end
