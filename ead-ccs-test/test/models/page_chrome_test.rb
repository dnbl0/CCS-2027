require "test_helper"

class PageChromeTest < ActiveSupport::TestCase
  # Stands in for the header: the record's title and the way back to the results, asked for on a record page only
  Record = Struct.new(:record_title, :results_url)
  RECORD = Record.new("Bust of Percy Grainger", "/catalog?q=grainger")

  def chrome(controller, action, searching: false, page: RECORD)
    PageChrome.for(controller: controller, action: action, searching: searching, page: page)
  end

  test "the home page: no trail, no banner, the saved bar over the hero photo and in the phone menu" do
    home = chrome("pages", "home")

    assert_equal [], home.breadcrumbs
    assert_nil home.banner
    assert_equal :hero, home.saved_bar
    assert home.saved_link_in_phone_menu?
  end

  test "a content page draws its own breadcrumb strip, so the header has no trail and no saved bar" do
    about = chrome("pages", "about")

    assert_equal [], about.breadcrumbs
    assert_nil about.banner
    assert_equal :page, about.saved_bar
    assert_not about.saved_link_in_phone_menu?
  end

  test "the bare search page: the search banner, the saved bar in the header's top strip" do
    bare = chrome("catalog", "index")

    assert_equal [], bare.breadcrumbs
    assert_equal :search, bare.banner
    assert_equal :header, bare.saved_bar
    assert bare.saved_link_in_phone_menu?
  end

  test "search results: a Search results trail, the search banner, the saved bar in the breadcrumb strip" do
    results = chrome("catalog", "index", searching: true)

    assert_equal [ [ "Search results", nil ] ], results.breadcrumbs
    assert_equal :search, results.banner
    assert_equal :breadcrumb, results.saved_bar
    assert_not results.saved_link_in_phone_menu?
  end

  test "a record: back to the visitor's results, then the record's title, under the record's title band" do
    record = chrome("catalog", "show")

    assert_equal [ [ "Search results", "/catalog?q=grainger" ], [ "Bust of Percy Grainger", nil ] ], record.breadcrumbs
    assert_equal :record, record.banner
    assert_equal :breadcrumb, record.saved_bar
  end

  test "a browse page draws its own breadcrumb strip, so the saved bar is not also in the header" do
    browse = chrome("browse", "index")

    assert_equal [], browse.breadcrumbs
    assert_equal :page, browse.saved_bar
  end

  test "advanced search: its own trail and page banner, not the search banner" do
    advanced = chrome("catalog", "advanced_search")

    assert_equal [ [ "Advanced search", nil ] ], advanced.breadcrumbs
    assert_equal :advanced_search, advanced.banner
  end

  test "any other catalog page keeps the search banner; any other page has no banner; neither has a trail" do
    assert_equal [ [], :search, :header ], chrome("catalog", "facet").deconstruct
    assert_equal [ [], nil, :header ], chrome("errors", "not_found").deconstruct
  end

  test "saved records: the saved list's trail and no banner" do
    saved = chrome("bookmarks", "index")

    assert_equal [ [ I18n.t("nexus_ccs.saved.list_title"), nil ] ], saved.breadcrumbs
    assert_nil saved.banner
    assert_equal :breadcrumb, saved.saved_bar
  end

  test "the record's title and the results link are only asked for on a record page" do
    nobody = Object.new # raises NoMethodError if asked

    assert_equal [ [ "Search results", nil ] ], chrome("catalog", "index", searching: true, page: nobody).breadcrumbs
    assert_equal [], chrome("pages", "home", page: nobody).breadcrumbs
  end

  test "a stock record page (Blacklight's own page in the site header): a record trail and no banner" do
    stock = PageChrome.stock_record(record_title: "Test record", results_url: "/catalog")

    assert_equal [ [ "Search results", "/catalog" ], [ "Test record", nil ] ], stock.breadcrumbs
    assert_nil stock.banner
    assert_equal :breadcrumb, stock.saved_bar
  end

  test "the search history and saved searches pages: a trail with their own name and no banner, as the page brings one" do
    { "search_history" => "Search history", "saved_searches" => "Saved searches", "lists" => "Your lists", "my_data" => "Delete my data" }.each do |controller, name|
      page = chrome(controller, "index")

      assert_equal [ [ name, nil ] ], page.breadcrumbs
      assert_nil page.banner
      assert_equal :breadcrumb, page.saved_bar
    end
  end

  test "the access request form: the way back to the results, then the page, with no banner" do
    form = chrome("access_requests", "new")

    assert_equal [ [ "Search results", "/catalog?q=grainger" ], [ "Request access", nil ] ], form.breadcrumbs
    assert_nil form.banner
    assert_equal :breadcrumb, form.saved_bar
  end

  test "the selection page: a trail of its own, no banner, the saved bar in the breadcrumb strip" do
    selection = chrome("selections", "show")

    assert_equal [ [ "Selected records", nil ] ], selection.breadcrumbs
    assert_nil selection.banner
    assert_equal :breadcrumb, selection.saved_bar
  end

  test "the comparison page: a one-step trail, no banner, the saved bar in the breadcrumb strip" do
    compare = chrome("compare", "show")

    assert_equal [ [ I18n.t("nexus_ccs.compare.title"), nil ] ], compare.breadcrumbs
    assert_nil compare.banner
    assert_equal :breadcrumb, compare.saved_bar
  end
end
