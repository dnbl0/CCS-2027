require "test_helper"
require_relative "../support/discovery_records"
require_relative "../support/env_override"
require_relative "../support/request_counter"

# Similar records, Featured, Pick of the day and Trending (docs/similar-and-trending.md). Solr is stood in for (DiscoveryRecords), so
# these run in the CI job that has no core; the system test and the model tests check the real thing where there is one.
class DiscoveryTest < ActionDispatch::IntegrationTest
  include DiscoveryRecords
  include EnvOverride
  include RequestCounter

  CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
  WITHHELD_THUMB = "/digital-assets/thumbs/withheld-asset.jpg"
  SENSITIVE_THUMB = "/digital-assets/thumbs/sensitive-asset.jpg"

  setup do
    RecordView.reset_pending!
    @featured_ids = FeaturedRecords.configured.first(4).map { |pick| pick["id"] }
  end

  teardown { RecordView.reset_pending! }

  def records
    featured = @featured_ids.map { |id| open_record(id) }
    featured + [ open_record("emu-source"), open_record("emu-a"), open_record("emu-b", creator_ssim: [ "B" ]),
                 withheld_record("emu-withheld", thumbnail_path_ssi: WITHHELD_THUMB), sensitive_record("emu-sensitive", thumbnail_path_ssi: SENSITIVE_THUMB) ]
  end

  def similar = { "emu-a" => 50, "emu-withheld" => 48, "emu-sensitive" => 47, "emu-b" => 45 }

  def answer(extra = {}) = discovery_solr(records: records, similar: similar.merge(extra))

  def solr(answer = self.answer, &block)
    with_seeded_menu_cache { with_canned_search(answer, &block) }
  end

  # --- Similar records ---

  test "a record's similar records come as a Turbo frame of the site's result cards, without the record, a withheld or a sensitive one" do
    solr { get "/catalog/emu-source/similar" }

    assert_response :success
    assert_select "turbo-frame#similar-records section[aria-labelledby=similar-records-heading]" do
      assert_select "h2#similar-records-heading", text: "Similar records"
      assert_select "article.result-card", count: 2
      assert_select "article[data-document-id='emu-a']"
      assert_select "article[data-document-id='emu-b']"
    end
    assert_select "article[data-document-id='emu-source']", count: 0
    assert_no_match(/withheld-asset|sensitive-asset/, response.body)
    assert_no_match(/emu-withheld|emu-sensitive/, response.body)
  end

  test "the fragment is kept out of search results and is not a page of its own" do
    solr { get "/catalog/emu-source/similar" }

    assert_includes response.headers["X-Robots-Tag"], "noindex"
    assert_includes response.headers["X-Robots-Tag"], "nofollow"
    assert_no_match(/<html/i, response.body)
  end

  test "fewer than two similar records leave the section out: 204, no content" do
    solr(discovery_solr(records: records, similar: { "emu-a" => 50 })) { get "/catalog/emu-source/similar" }

    assert_response :no_content
    assert_empty response.body
  end

  test "a withheld record and a sensitive record get no section, and Solr is asked for no recommendations" do
    %w[emu-withheld emu-sensitive].each do |id|
      solr { |seen| get "/catalog/#{id}/similar"; assert(seen.none? { |params| params.to_h.key?(:sim_mlt) }, "#{id} was given recommendations") }

      assert_response :no_content, id
    end
  end

  test "an id that is not in the index is a 404" do
    solr { get "/catalog/emu-nothing/similar" }
    assert_response :not_found
  end

  test "Solr failing leaves the section out with no error" do
    solr(->(_params) { raise Blacklight::Exceptions::ECONNREFUSED, "down" }) { get "/catalog/emu-source/similar" }
    assert_response :no_content

    solr(->(_params) { raise Faraday::TimeoutError }) { get "/catalog/emu-source/similar" }
    assert_response :no_content
  end

  test "an id made to look like part of a query is only an id" do
    solr { |seen| get "/catalog/#{ERB::Util.url_encode('x" OR *:*')}/similar" }

    assert_response :not_found
  end

  # --- The record page's frame ---

  def with_found_record(document)
    original = Blacklight::Solr::Repository.instance_method(:find)
    Blacklight::Solr::Repository.send(:define_method, :find) do |_id = nil, _params = {}|
      Blacklight::Solr::Response.new({ "response" => { "docs" => [ document ], "numFound" => 1, "start" => 0 } }, {}, document_model: SolrDocument, blacklight_config: blacklight_config)
    end
    yield
  ensure
    Blacklight::Solr::Repository.send(:define_method, :find, original) if original
  end

  def record_page(document, agent: CHROME)
    with_seeded_menu_cache { with_found_record(document) { get "/catalog/#{document['id']}", headers: { "User-Agent" => agent } } }
  end

  test "the record page holds an empty lazy frame that loads the similar records, and no recommendations of its own" do
    record_page(open_record("emu-source"))

    assert_response :success
    assert_select "turbo-frame#similar-records[loading=lazy][src='/catalog/emu-source/similar']"
    assert_select "turbo-frame#similar-records *", count: 0
    assert_select "#similar-records-heading", count: 0
  end

  test "a record with a withheld asset, or a sensitive one, has no Similar records section at all" do
    [ withheld_record("emu-withheld"), sensitive_record("emu-sensitive") ].each do |document|
      record_page(document)

      assert_response :success
      assert_select "turbo-frame#similar-records", count: 0
    end
  end

  # --- Counting views ---

  test "a person's view of an open record is counted, and a view-only record too" do
    record_page(open_record("emu-source"))
    record_page(view_only_record("emu-vo"))

    assert_equal({ [ Date.current, "emu-source" ] => 1, [ Date.current, "emu-vo" ] => 1 }, RecordView.pending_counts)
  end

  test "crawlers, scripts and requests without a user agent are not counted" do
    [ "Googlebot/2.1", "GPTBot/1.1", "curl/8.4.0", "python-requests/2.31", "" ].each { |agent| record_page(open_record("emu-source"), agent: agent) }

    assert_empty RecordView.pending_counts
  end

  test "views of a withheld record and of a sensitive record are not counted" do
    record_page(withheld_record("emu-withheld"))
    record_page(sensitive_record("emu-sensitive"))

    assert_empty RecordView.pending_counts
  end

  test "the count is off with TRENDING_ENABLED=off" do
    with_env("TRENDING_ENABLED" => "off") { record_page(open_record("emu-source")) }

    assert_empty RecordView.pending_counts
  end

  test "a view stores nothing about the visitor: only the record, the day and the number reach the table" do
    RecordView.delete_all
    record_page(open_record("emu-source"))
    RecordView.flush

    row = RecordView.sole
    assert_equal({ "document_id" => "emu-source", "views" => 1, "day" => Date.current }, row.attributes.slice("document_id", "views", "day"))
  end

  # --- Home page and /discover ---

  test "the home page holds a heading, a visible link to /discover and a lazy frame, and no records, no Solr request and one query at most" do
    result = nil
    with_seeded_menu_cache do
      get "/"
      result = count_requests { get "/" }
    end

    assert_response :success
    assert_select "section[aria-labelledby=home-discover-heading] h2#home-discover-heading", text: "Featured and trending"
    assert_select "section[aria-labelledby=home-discover-heading] a[href='/discover']", text: "See all featured and trending records"
    assert_select "turbo-frame#home-discover.discover-frame[loading=lazy][src='/discover/frame']"
    assert_select ".result-card", count: 0
    assert_equal 0, result.solr
    assert_operator result.sql, :<=, 1
  end

  test "the home frame has the pick of the day, the featured records and no trending section while the data is thin" do
    solr { get "/discover/frame" }

    assert_response :success
    assert_select "turbo-frame#home-discover" do
      assert_select "h3#discover-pick-heading", text: "Pick of the day"
      assert_select "h3#discover-featured-heading", text: "Featured records"
      assert_select "#discover-trending-heading", count: 0
      assert_select ".discover-section--featured .result-card", count: 4
    end
    assert_select "h2", count: 0
  end

  test "the home frame is not a page to index" do
    solr { get "/discover/frame" }

    assert_includes response.headers["X-Robots-Tag"], "noindex"
  end

  test "enough views add a Trending section, most viewed first" do
    [ [ "emu-a", 9 ], [ "emu-b", 5 ], [ @featured_ids.first, 7 ] ].each { |id, views| RecordView.create!(document_id: id, day: Date.current, views: views) }

    solr { get "/discover" }

    assert_select "h2#discover-trending-heading", text: "Trending records"
    assert_equal [ "emu-a", @featured_ids.first, "emu-b" ], css_select(".discover-section--trending article").map { |node| node["data-document-id"] }
    assert_match(/last 7 days/, css_select(".discover-section--trending .discover-section__description").text)
  end

  test "trending leaves out a record that is withheld or sensitive, with its image" do
    [ [ "emu-a", 9 ], [ "emu-b", 5 ], [ @featured_ids.first, 7 ], [ "emu-withheld", 30 ], [ "emu-sensitive", 30 ] ].each do |id, views|
      RecordView.create!(document_id: id, day: Date.current, views: views)
    end

    solr { get "/discover" }

    assert_select ".discover-section--trending article", count: 3
    assert_no_match(/withheld-asset|sensitive-asset|emu-withheld|emu-sensitive/, response.body)
  end

  test "TRENDING_ENABLED=off removes the Trending section, and the others stay" do
    3.times { |n| RecordView.create!(document_id: [ "emu-a", "emu-b", @featured_ids.first ][n], day: Date.current, views: 9) }

    with_env("TRENDING_ENABLED" => "off") { solr { get "/discover" } }

    assert_select ".discover-section--trending", count: 0
    assert_select ".discover-section--featured"
  end

  test "/discover is a public page: one h1, headings in order, canonical, indexable when indexing is on, and the trail" do
    with_env("SEO_INDEXING" => "on") { solr { get "/discover" } }

    assert_response :success
    assert_select "h1", text: "Discover", count: 1
    assert_select "main#main-content"
    assert_select "h2#discover-pick-heading"
    assert_select "h2#discover-featured-heading"
    assert_select "link[rel=canonical][href$='/discover']"
    assert_select "meta[name=description][content*='Featured records']"
    assert_not_includes response.headers["X-Robots-Tag"], "noindex"
    assert_select "nav[aria-label*=readcrumb] [aria-current], .breadcrumb-bar [aria-current]", text: /Discover/
  end

  test "/discover lists the placeholder blurbs of the curated records" do
    solr { get "/discover" }

    assert_select ".discover-cards__blurb", text: /Placeholder blurb/, minimum: 1
  end

  test "no section on /discover or the home frame shows a withheld or sensitive record, or either one's image" do
    solr { get "/discover" }
    page = response.body
    solr { get "/discover/frame" }

    [ page, response.body ].each do |body|
      assert_no_match(/withheld-asset|sensitive-asset|emu-withheld|emu-sensitive/, body)
    end
  end

  test "with Solr down the home frame says there is nothing to feature, and /discover says so too, both with success" do
    solr(->(_params) { raise Blacklight::Exceptions::ECONNREFUSED, "down" }) { get "/discover" }
    assert_response :success
    assert_select ".saved-empty__text", text: /nothing to feature/
    assert_select "a[href='/catalog']", minimum: 1

    solr(->(_params) { raise Blacklight::Exceptions::ECONNREFUSED, "down" }) { get "/discover/frame" }
    assert_response :success
    assert_select "turbo-frame#home-discover .discover-frame__note", text: /nothing to feature/
  end

  test "/discover is in the sitemap" do
    sitemap = Sitemap.new(base_url: "https://example.test", records: -> { [] })
    assert_includes sitemap.urls.map(&:first), "https://example.test/discover"
  end

  # --- Privacy ---

  test "the privacy notice and Delete my data say that view counts hold nothing personal" do
    get "/privacy"
    assert_select "#view-counts", text: /does not store who looked/

    get "/my_data"
    assert_select "main", text: /no cookie, visitor number or address/
  end

  # --- Performance, against the real index ---

  test "the record page still makes one Solr request, and the similar frame two: the record, then its neighbours" do
    needs_solr
    page = frame = nil
    with_seeded_menu_cache do
      get "/catalog/emu-10247"
      page = count_requests { get "/catalog/emu-10247" }
      frame = count_requests { get "/catalog/emu-10247/similar" }
    end

    assert_equal 1, page.solr, page.solr_requests.join("\n")
    assert_equal 2, frame.solr, frame.solr_requests.join("\n")
    assert_operator frame.sql, :<=, 2
    assert_response :success
  end

  test "the home frame makes at most four Solr requests and two queries" do
    needs_solr
    get "/discover/frame"
    result = count_requests { get "/discover/frame" }

    assert_response :success
    assert_operator result.solr, :<=, 4, result.solr_requests.join("\n")
    assert_operator result.sql, :<=, 2, result.statements.join("\n")
  end
end
