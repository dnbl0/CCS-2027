require "test_helper"
require_relative "../support/env_override"

# What each kind of page says in its head, and in X-Robots-Tag, for search engines, social networks and AI crawlers (CCS-128, CCS-127).
# Record pages are handed a document in place of Solr, as in StockCatalogTest; the results page needs the real core.
class SeoHeadTest < ActionDispatch::IntegrationTest
  include EnvOverride

  def self.record(id, fields = {})
    SolrDocument.new({ "id" => id, "title_tsim" => [ "Record #{id}" ], "format" => [ "Work" ], "collection_ssim" => [ "University Art Collection" ],
                       "description_tsim" => [ "A description of #{id}. " * 20 ], "creator_ssim" => [ "A. Maker" ],
                       "licence_type_ssim" => [ "Public domain - Copyright expired" ], "thumbnail_path_ssi" => "/digital-assets/thumbs/#{id}.jpg",
                       "digital_asset_paths_ssim" => [ "/digital-assets/thumbs/#{id}.jpg" ], "digital_asset_large_paths_ssim" => [ "/digital-assets/large/#{id}.jpg" ] }.merge(fields)).tap do |doc|
      doc.instance_variable_set(:@response, Blacklight::Solr::Response.new({ "response" => { "docs" => [] } }, {}))
    end
  end

  DOCS = {
    "open" => record("open"),
    "viewonly" => record("viewonly", "licence_type_ssim" => [ "Copyright - Current" ]),
    "request" => record("request", "licence_type_ssim" => [ "ICIP Rights" ]),
    "sensitive" => record("sensitive", "restrictions_tsi" => [ "Not for publishing. Culturally sensitive images." ]),
    "evil" => record("evil", "title_tsim" => [ "\"><script>alert(1)</script>" ], "description_tsim" => [ "</script><script>alert(2)</script>" ])
  }.freeze

  FakeService = Struct.new(:doc) { def fetch(*) = doc }

  module FakeSolr
    def search_service = DOCS.key?(params[:id]) ? FakeService.new(DOCS.fetch(params[:id])) : super
  end
  [ CatalogController, StockCatalogController, BrandedStockCatalogController ].each { |controller| controller.prepend(FakeSolr) }

  setup do
    Rails.configuration.x.stock_record_ids = %w[open request]
    @env = { "SEO_INDEXING" => "on" }
  end
  teardown { Rails.configuration.x.stock_record_ids = nil }

  def robots_meta = css_select("meta[name=robots]").first&.[]("content")
  def canonical = css_select("link[rel=canonical]").first&.[]("href")
  def meta(name) = css_select("meta[name='#{name}'], meta[property='#{name}']").first&.[]("content")
  def json_ld = css_select("script[type='application/ld+json']").map { |tag| JSON.parse(tag.text) }

  test "the home page: description, canonical, Open Graph, Twitter card and the WebSite structured data with its SearchAction" do
    with_env(@env) { get "/" }

    assert_response :success
    assert_equal "http://www.example.com/", canonical
    assert_match(/cultural collections/, meta("description"))
    assert_equal "website", meta("og:type")
    assert_equal "Collections Navigator - University of Melbourne", meta("og:title")
    assert_equal "summary", meta("twitter:card")
    assert_nil meta("og:image")
    site = json_ld.sole
    assert_equal "WebSite", site["@type"]
    assert_equal "http://www.example.com/catalog?q={search_term_string}", site.dig("potentialAction", "target", "urlTemplate")
    assert_equal "noai, noimageai", robots_meta
    assert_equal "noai, noimageai", response.headers["X-Robots-Tag"]
  end

  test "help and about have their own description and canonical, and are indexed" do
    with_env(@env) { get "/help" }
    assert_equal "http://www.example.com/help", canonical
    assert_match(/Help for Collections Navigator/, meta("description"))
    assert_equal "noai, noimageai", robots_meta

    with_env(@env) { get "/about" }
    assert_equal "http://www.example.com/about", canonical
    assert_match(/rich and diverse cultural collections/, meta("description"))
  end

  test "the advanced search page is indexed, with its canonical" do
    with_env(@env) { get "/catalog/advanced", params: { utm_source: "x" } }

    assert_equal "http://www.example.com/catalog/advanced", canonical
    assert_equal "noai, noimageai", robots_meta
  end

  test "an open record: title, trimmed description, canonical, thumbnail in Open Graph and JSON-LD, indexed" do
    with_env(@env) { get "/catalog/open", params: { utm_source: "x", q: "y" } }

    assert_response :success
    assert_equal "http://www.example.com/catalog/open", canonical
    assert_operator meta("description").length, :<=, 155
    assert_equal "article", meta("og:type")
    assert_equal "http://www.example.com/digital-assets/thumbs/open.jpg", meta("og:image")
    assert_equal "summary_large_image", meta("twitter:card")
    assert_equal "http://www.example.com/digital-assets/thumbs/open.jpg", meta("twitter:image")
    data = json_ld.sole
    assert_equal "CreativeWork", data["@type"]
    assert_equal "http://www.example.com/digital-assets/thumbs/open.jpg", data["image"]
    assert_equal "noai, noimageai", robots_meta
    assert_equal "noai, noimageai", response.headers["X-Robots-Tag"]
    assert_no_match(/digital-assets\/large/, css_select("head").to_s)
  end

  test "a view-only record is indexed but has no image in any tag" do
    with_env(@env) { get "/catalog/viewonly" }

    assert_equal "noai, noimageai", robots_meta
    assert_nil meta("og:image")
    assert_nil meta("twitter:image")
    assert_nil json_ld.sole["image"]
    assert_equal "summary", meta("twitter:card")
  end

  test "a request-tier record and a sensitive record leak no asset address, are noindex, follow, and have a general description and no JSON-LD" do
    %w[request sensitive].each do |id|
      with_env(@env) { get "/catalog/#{id}" }

      head = css_select("head").to_s
      assert_response :success, id
      assert_no_match(/digital-assets/, head, id)
      assert_equal "noindex, follow, noai, noimageai", robots_meta, id
      assert_equal "noindex, follow, noai, noimageai", response.headers["X-Robots-Tag"], id
      assert_empty json_ld, id
      assert_nil meta("og:image"), id
      assert_no_match(/A description of/, meta("description"), id)
    end
  end

  test "a record's own words cannot break out of the head" do
    with_env(@env) { get "/catalog/evil" }

    assert_equal 1, css_select("script[type='application/ld+json']").size
    assert_equal "\"><script>alert(1)</script>", JSON.parse(css_select("script[type='application/ld+json']").first.text)["name"]
    assert_empty css_select("head script").select { |tag| tag.text.include?("alert") && tag["type"] != "application/ld+json" }
    assert_not_includes css_select("head").to_s.sub(%r{<title>.*?</title>}m, ""), "<script>alert"
  end

  test "the stock record pages are a copy of the record page: noindex, nofollow and canonical to the record" do
    %w[/stock/open /branded-stock/open].each do |path|
      with_env(@env) { get path }

      assert_response :success, path
      assert_equal "noindex, nofollow, noai, noimageai", robots_meta, path
      assert_equal "http://www.example.com/catalog/open", canonical, path
      assert_equal "noindex, nofollow, noai, noimageai", response.headers["X-Robots-Tag"], path
    end
  end

  test "a request-tier record's stock page leaks no asset address into the head" do
    with_env(@env) { get "/stock/request" }

    assert_no_match(/digital-assets/, css_select("head").to_s)
  end

  test "with indexing off (a test or staging copy) every page is noindex, nofollow, and has no social tags" do
    %w[/ /help /catalog/open].each do |path|
      get path
      assert_equal "noindex, nofollow, noai, noimageai", response.headers["X-Robots-Tag"], path
      assert_equal "noindex, nofollow, noai, noimageai", robots_meta, path
    end
  end

  test "BOT_CONTROLS=off removes the AI tags and leaves indexing as it was" do
    with_env(@env.merge("BOT_CONTROLS" => "off")) { get "/help" }

    assert_nil response.headers["X-Robots-Tag"].presence
    assert_equal "", robots_meta
  end

  test "the results page: indexed for the default search, noindex follow with a search or a later page, canonical without sort or view" do
    needs_solr
    with_env(@env) { get "/catalog", params: { f: { has_digital_asset: [ "with" ] }, search_field: "all_fields", sort: "title_si asc", view: "list", per_page: "24" } }

    assert_response :success
    assert_equal "noai, noimageai", robots_meta
    assert_equal "http://www.example.com/catalog?f%5Bhas_digital_asset%5D%5B%5D=with&search_field=all_fields", canonical
    assert_match(/Search results from/, meta("description"))

    with_env(@env) { get "/catalog", params: { q: "chest", search_field: "all_fields", f: { has_digital_asset: [ "with" ] } } }
    assert_equal "noindex, follow, noai, noimageai", robots_meta
    assert_equal "noindex, follow, noai, noimageai", response.headers["X-Robots-Tag"]
    assert_match(/Search results for “chest”/, meta("description"))

    with_env(@env) { get "/catalog", params: { f: { has_digital_asset: [ "with" ] }, search_field: "all_fields", page: "2" } }
    assert_equal "noindex, follow, noai, noimageai", robots_meta
    assert_match(/page=2/, canonical)
  end
end
