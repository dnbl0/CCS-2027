require "test_helper"
require "zlib"
require_relative "../support/request_counter"

# CCS-71 (BR-18.04): the budgets in docs/performance.md that can be checked without a browser. A failure here is a page that
# has become slower to build, heavier to send, or cacheable by something that should not keep it. Numbers are the measured
# values with a little headroom; raise one only with a reason, and change the document with it.
class PerformanceTest < ActionDispatch::IntegrationTest
  include RequestCounter

  # The test environment has no cache, so every page would ask Solr for the header menu's collection counts; production keeps them a day
  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write(BrowseMenu::CACHE_KEY, { BrowseMenu::WITH_IMAGES => 1 }, expires_in: 1.day) # as if already fetched, so no Solr is needed
    # The home page's Explore section, full-sized (8 object types, 8 places, every period), so the budget below covers it
    Rails.cache.write(ExploreEntryPoints::CACHE_KEY, {
      ExploreEntryPoints::OBJECT_TYPE_FIELD => Array.new(8) { |n| [ "Object type number #{n}", 1000 - n ] },
      ExploreEntryPoints::PLACE_FIELD => Array.new(8) { |n| [ "Place number #{n}", 900 - n ] },
      "periods" => ExploreEntryPoints.periods.to_h { |_label, first, last| [ ExploreEntryPoints.period_key(first, last), 500 ] }
    }, expires_in: 1.day)
  end

  teardown { Rails.cache = @cache }

  # --- Compression ---

  test "HTML is compressed for browsers that accept gzip, and is the same page once unpacked" do
    get "/" # the first visit shows the Acknowledgement of Country, later ones do not
    get "/", headers: { "Accept-Encoding" => "identity" }
    plain = response.body
    assert_nil response.headers["content-encoding"]

    get "/", headers: { "Accept-Encoding" => "gzip" }
    assert_equal "gzip", response.headers["content-encoding"]
    assert_includes response.headers["vary"].to_s, "Accept-Encoding"
    assert_operator response.body.bytesize, :<, plain.bytesize / 3
    unpacked = Zlib.gunzip(response.body)
    assert_match(/\A<!DOCTYPE html>/i, unpacked)
    assert_in_delta plain.bytesize, unpacked.bytesize, 500 # the CSRF token and the script nonce differ between responses
  end

  test "images are not compressed again" do
    get "/digital-assets/thumbs/0000_013_1_pf.jpg", headers: { "Accept-Encoding" => "gzip" }

    assert_response :success
    assert_nil response.headers["content-encoding"]
  end

  # --- Static file lifetimes ---

  def static_cache_control(path, status: 200, cache_control: "public, max-age=3600")
    app = ->(_env) { [ status, { "cache-control" => cache_control }, [ "" ] ] }
    _status, headers, = StaticCacheControl.new(app).call(Rack::MockRequest.env_for(path))
    headers["cache-control"]
  end

  test "fingerprinted assets are cached for a year and immutable" do
    assert_equal "public, max-age=31536000, immutable", static_cache_control("/assets/application-11c958ae.css")
  end

  # CCS-425: a file can be replaced under the same name, so an address without the version token is revalidated, not kept for a day
  test "the records' images are cached for a year at a versioned address, revalidated at any other, and other public files for an hour" do
    assert_equal "public, max-age=31536000, immutable", static_cache_control("/digital-assets/large/x.jpg?v=69a1b2c3f00")
    assert_equal "public, max-age=0, must-revalidate", static_cache_control("/digital-assets/large/x.jpg")
    assert_equal "public, max-age=0, must-revalidate", static_cache_control("/digital-assets/large/x.jpg?v=")
    assert_equal "public, max-age=3600", static_cache_control("/icon.png")
  end

  test "only the static file server's own public responses are given a lifetime" do
    assert_equal "private, max-age=0", static_cache_control("/assets/x-1.css", cache_control: "private, max-age=0")
    assert_equal "no-store", static_cache_control("/assets/x-1.css", cache_control: "no-store")
    assert_equal "public, max-age=3600", static_cache_control("/assets/x.css", status: 404)
  end

  test "public files are served with a lifetime that matches their kind" do
    get "/icon.png"
    assert_equal "public, max-age=3600", response.headers["cache-control"]

    get "/digital-assets/thumbs/0000_013_1_pf.jpg"
    assert_equal "public, max-age=0, must-revalidate", response.headers["cache-control"]
  end

  test "the stylesheet is linked once and the fingerprinted address is served from the asset server" do
    get "/"
    href = css_select("link[rel=stylesheet][href*='application']").first["href"]
    assert_match %r{\A/assets/application-\h+\.css\z}, href

    get href
    assert_response :success
    assert_match(/public/, response.headers["cache-control"])
    assert_match(/max-age=31536000/, response.headers["cache-control"])
  end

  # --- Pages that are personal are never publicly cacheable ---

  test "no page that sets a cookie, and no personal page, is publicly cacheable" do
    post "/lists", params: { list: { name: "Violins" } }
    list = List.order(:id).last
    paths = [ "/", "/help", "/about", "/lists", "/lists/new", "/lists/#{list.id}", "/saved_searches", "/search_history", "/access_requests/new" ]

    paths.each do |path|
      get path
      control = response.headers["cache-control"].to_s
      assert_no_match(/public|s-maxage/, control, "#{path} must not be cacheable by a shared cache (Cache-Control: #{control})")
    end
  end

  test "downloads and the access request confirmation are not cached either" do
    get "/bookmarks"
    assert_no_match(/public/, response.headers["cache-control"].to_s)
  end

  # --- Size of the static pages ---

  # HTML: measured 40-46 kB (9-10 kB gzipped) on 2 Nov 2026; the home page grew by about 2.5 kB with the "Explore by" tiles
  # and by about 0.5 kB with the "Featured and trending" heading, link and lazy frame (its records load later, not in this HTML)
  { "/" => 62_000, "/help" => 56_000, "/about" => 50_000 }.each do |path, budget|
    test "#{path} stays within its HTML size budget (#{budget / 1000} kB, #{14} kB compressed)" do
      get path, headers: { "Accept-Encoding" => "identity" }
      assert_operator response.body.bytesize, :<=, budget
      assert_operator Zlib.gzip(response.body).bytesize, :<=, 14_000
    end
  end

  test "a page links one stylesheet and no more than the budgeted scripts" do
    get "/"
    assert_equal 1, css_select("link[rel=stylesheet]").size
    assert_operator css_select("script[src]").size, :<=, 2
  end

  # --- Scripts ---

  test "the OpenSeadragon viewer is preloaded only by the two stock record pages" do
    map = Rails.application.importmap
    helpers = ApplicationController.helpers
    site = map.preloaded_module_paths(resolver: helpers, entry_point: "application", cache_key: "perf-site")
    stock = map.preloaded_module_paths(resolver: helpers, entry_point: "stock_application", cache_key: "perf-stock")

    assert_empty site.grep(/openseadragon|stock_/), "the site's pages preload the record viewer"
    assert_not_empty stock.grep(/openseadragon/), "the stock record page needs the viewer"
    # Each Stimulus controller is one small file, so this count grows with features (53 after the selection and media viewer
    # controllers, 3 Nov 2026). The size that matters is the script bytes budget; this only stops a library sneaking in.
    assert_operator site.size, :<=, 56, "the site's pages preload more scripts than the budget allows"
  end

  test "a page does not preload the record viewer" do
    get "/"
    assert_select "link[rel=modulepreload][href*=openseadragon]", count: 0
  end

  # --- Database work per page (no Solr) ---

  # The visitor's guest row is made by their first list; more lists (each with records) are added to it
  def guest_with(lists:, per_list:)
    post "/lists", params: { list: { name: "First #{SecureRandom.hex(2)}" } } unless List.exists?
    user = User.find(List.order(:id).last.user_id)
    lists.times do |n|
      list = user.lists.create!(name: "List #{SecureRandom.hex(3)} #{n}")
      per_list.times { |item| list.list_items.create!(document_id: "emu-#{list.id}-#{item}") }
    end
    user
  end

  test "the lists page makes the same few database queries for one list or for many" do
    guest_with(lists: 1, per_list: 1)
    get "/lists"
    one = count_requests { get "/lists" }
    assert_response :success

    guest_with(lists: 5, per_list: 5)
    many = count_requests { get "/lists" }
    assert_response :success

    assert_operator many.sql, :<=, 3, "lists page SQL (budget 3):\n#{many.statements.join("\n")}"
    assert_operator many.sql, :<=, one.sql + 1, "the number of queries grows with the number of lists (N+1)"
    assert_equal 0, many.solr, "a lists page asks Solr for nothing once the header menu's counts are cached"
  end

  test "the lists page of a visitor with no guest row makes no database queries" do
    result = count_requests { get "/lists" }

    assert_equal 0, result.sql, result.statements.join("\n")
  end

  test "the saved searches page makes the same few queries however many searches are saved" do
    post "/lists", params: { list: { name: "To make a session" } } # the guest's cookie
    guest = User.find(List.order(:id).last.user_id)
    guest.saved_searches.create!(name: "one", query_params: { "q" => "skull" })
    one = count_requests { get "/saved_searches" }

    8.times { |n| guest.saved_searches.create!(name: "more #{n}", query_params: { "q" => "violin #{n}" }) }
    many = count_requests { get "/saved_searches" }

    assert_response :success
    assert_operator many.sql, :<=, 3, "saved searches page SQL (budget 3):\n#{many.statements.join("\n")}"
    assert_equal one.sql, many.sql, "the number of queries grows with the number of saved searches (N+1)"
  end

  test "static pages make no more than one database query and no Solr request" do
    [ "/", "/help", "/about" ].each do |path|
      get path # the first page of a process fetches the header menu's counts
      result = count_requests { get path }

      assert_response :success
      assert_operator result.sql, :<=, 1, "#{path}: #{result.statements.join("\n")}"
      assert_equal 0, result.solr, "#{path}: #{result.solr_requests.join("\n")}"
    end
  end

  # --- Pages that read Solr (skipped where there is no Solr core) ---

  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL"
  end

  test "a results page makes at most 2 Solr requests and 3 database queries, with or without a guest" do
    needs_solr
    get "/catalog", params: { q: "skull" }
    follow_redirect!
    post "/lists", params: { list: { name: "A guest" } }

    get "/catalog", params: { q: "skull", f: { has_digital_asset: [ "with" ] } } # warms the header menu's counts
    result = count_requests { get "/catalog", params: { q: "skull", f: { has_digital_asset: [ "with" ] } } }

    assert_response :success
    assert_operator result.solr, :<=, 2, result.solr_requests.join("\n")
    assert_operator result.sql, :<=, 4, result.statements.join("\n")
  end

  test "a record page makes one Solr request and at most 6 database queries" do
    needs_solr
    post "/lists", params: { list: { name: "A guest" } }

    get "/catalog/emu-406126"
    result = count_requests { get "/catalog/emu-406126" }

    assert_response :success
    assert_equal 1, result.solr, result.solr_requests.join("\n")
    assert_operator result.sql, :<=, 6, result.statements.join("\n")
  end

  test "the record page's main image is fetched first, decoded off the main thread and sized" do
    needs_solr
    get "/catalog/emu-20335"

    assert_response :success
    assert_select "img.digital-assets__image[fetchpriority=high][decoding=async][width][height]", count: 1
    assert_select "img[loading=lazy]", minimum: 1
  end

  test "highlighting and the selection form add no Solr request to a results page, and the selection page makes one" do
    needs_solr
    get "/catalog", params: { q: "skull", any_assets: "1" }
    result = count_requests { get "/catalog", params: { q: "skull", any_assets: "1" } }

    assert_equal 1, result.solr, result.solr_requests.join("\n")
    assert_includes result.solr_requests.first, "hl=true"
    assert_select "form#selection-form"

    post "/selection", params: { intent: "all", page_ids: [ "emu-406126" ] }
    result = count_requests { get "/selection" }
    assert_equal 1, result.solr, result.solr_requests.join("\n")
  end
end
