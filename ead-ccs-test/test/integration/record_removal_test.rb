require "test_helper"
require_relative "../support/solr_requests"
require_relative "../support/outages"
require_relative "../support/stub_records"
require_relative "../support/env_override"

# CCS-112: a record taken out of the site. Every request the app makes to Solr carries the filter (so it is absent from results,
# counts, facets, the sitemap, Similar records, Related objects, Featured...), and every page that names it answers 410 Gone.
# Solr is not needed: the requests are captured below the app (SolrRequests) and answered empty.
class RecordRemovalTest < ActionDispatch::IntegrationTest
  include SolrRequests
  include Outages
  include StubRecords
  include EnvOverride

  ID = "emu-removed-1"
  FILTER = "-{!terms f=id}#{ID}".freeze

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    SuppressedRecord.suppress!(ID, reason: "Removed at the family's request (test)", by: "Test")
  end

  teardown { Rails.cache = @cache }

  def assert_filtered(sent, what)
    assert_not_empty sent, "#{what} asked Solr nothing"
    sent.each { |request| assert_includes request.fq, FILTER, "#{what}: #{request.path} #{request.params.inspect} lacks the filter" }
  end

  def document(id = "emu-other-1") = stub_document(id, "creator_ssim" => [ "Judy" ], "collection_ssim" => [ "Grainger Museum Collection" ], "object_type_ssim" => [ "print" ])

  # --- Absent from every way of asking Solr ---

  test "the results page, a record page, the facet lists and the home page ask Solr with the filter" do
    [ "/catalog?q=lyre", "/catalog?q=lyre&f[collection_ssim][]=x", "/catalog/facet/collection_ssim", "/catalog/emu-other-1", "/" ].each do |path|
      sent = capture_solr do
        get path
        follow_redirect! while response.redirect?
      end
      assert_filtered sent, path
    end
  end

  test "the browse pages, the sitemap, the header's counts and the Explore tiles ask Solr with the filter" do
    assert_filtered capture_solr { BrowseMenu.counts }, "BrowseMenu"
    assert_filtered capture_solr { ExploreEntryPoints.counts }, "ExploreEntryPoints"
    assert_filtered capture_solr { BrowseHubs.values(BrowseHubs.find("object-types")) }, "BrowseHubs"
    assert_filtered capture_solr { BrowseHubs.period_values(Blacklight.default_index.connection) }, "BrowseHubs periods"
    assert_filtered capture_solr { Sitemap::RecordSource.call }, "Sitemap"
    assert_filtered capture_solr { with_env("SEO_INDEXING" => "on") { get "/sitemaps/1.xml" } }, "the sitemap page"
    assert_response :success
  end

  test "Discovery, Featured, Trending, Similar records, Related objects and record cards ask Solr with the filter" do
    assert_filtered capture_solr { Discovery.search(q: "*:*") }, "Discovery.search"
    assert_filtered capture_solr { Discovery.fetch([ "emu-other-1" ]) }, "Discovery.fetch"
    assert_filtered capture_solr { FeaturedRecords.pick_of_the_day }, "Pick of the day"
    assert_filtered capture_solr { FeaturedRecords.picks }, "Featured picks" if FeaturedRecords.configured.any?
    assert_filtered capture_solr { SimilarRecords.for(document) }, "SimilarRecords"
    assert_filtered capture_solr { RelatedObjects.for(document) }, "RelatedObjects"
    assert_filtered capture_solr { RecordSummaries.fetch(q: "*:*") }, "RecordSummaries"
    assert_filtered capture_solr { get "/catalog/emu-other-1/similar" }, "/similar"
    assert_filtered capture_solr { get "/discover" }, "/discover"
  end

  test "an entity page's profile asks Solr with the filter" do
    target = Data.define(:fq).new('creator_ssim:"Judy"')
    assert_filtered capture_solr { Browse::Profile.call(fq: target.fq) }, "Browse::Profile"
  end

  test "records in a list, a selection or a download are left out quietly" do
    controller = Class.new { include RecordLookup }.new
    sent = capture_solr { controller.send(:find_records, [ ID, "emu-other-1" ]) }

    assert_equal 1, sent.size
    assert_no_match(/#{ID}/, sent.first.params["ids"].to_s + sent.first.params["q"].to_s, "the removed id is not even asked for")
    assert_equal 0, capture_solr { controller.send(:find_records, [ ID ]) }.size
  end

  test "the saved records count does not include a removed record" do
    user = User.create!
    user.bookmarks.create!(document_id: ID, document_type: "SolrDocument")
    user.bookmarks.create!(document_id: "emu-other-1", document_type: "SolrDocument")
    session_controller = Class.new { include GuestBookmarks; attr_accessor :session }.new
    session_controller.session = { blacklight_guest_user_id: user.id }

    assert_equal 1, session_controller.saved_records_count
  end

  test "cached counts are rebuilt when a record is removed, not kept for the day" do
    SuppressedRecord.unsuppress!(ID)
    capture_solr { BrowseMenu.counts }
    sent = capture_solr { BrowseMenu.counts }
    assert_empty sent, "the second call is served from the cache while nothing changes"

    SuppressedRecord.suppress!(ID, reason: "r")
    assert_filtered capture_solr { BrowseMenu.counts }, "BrowseMenu after a removal"
  end

  # --- 410 Gone ---

  def assert_gone(path, method: :get, **options)
    as_production { public_send(method, path, **options) }
    assert_response :gone, "#{method} #{path}"
    assert_no_match(/Title of|digital-assets|thumbnail/i, response.body, "#{path} must show nothing of the record")
  end

  test "the record page, its citation and its Similar records are 410 Gone with a plain page, noindex, and no metadata" do
    assert_gone "/catalog/#{ID}"
    assert_select ".page-banner h1", "This record has been removed"
    assert_select ".error-page__code", "Error 410"
    assert_match(/noindex/, response.headers["X-Robots-Tag"])
    assert_empty css_select("script[type='application/ld+json']")
    assert_empty css_select("link[rel=canonical]")

    assert_gone "/catalog/#{ID}/citation"
    assert_gone "/catalog/#{ID}/similar"
  end

  test "the stock record pages are 410 Gone for a removed record" do
    SuppressedRecord.suppress!("emu-9044", reason: "r")

    assert_gone "/stock/emu-9044"
    assert_gone "/branded-stock/emu-9044"
  end

  test "the exports, the manifest, the sensitivity choice, the comparison and an access request are 410 Gone" do
    assert_gone "/catalog/#{ID}/metadata"
    assert_gone "/catalog/#{ID}/manifest.json"
    assert_gone "/catalog/#{ID}/sensitivity", method: :post, params: { choice: "view" }
    assert_gone "/compare/items", method: :post, params: { id: ID }
    assert_gone "/access_requests/new?document_id=#{ID}"
  end

  test "the embed answers 410 inside the frame, with no title and no image" do
    get "/embed/records/#{ID}"

    assert_response :gone
    assert_select "h1", "This record has been removed"
    assert_no_match(/digital-assets/, response.body)
    assert_match(/noindex/, response.headers["X-Robots-Tag"])
  end

  test "oEmbed answers 410 with no body" do
    get "/oembed", params: { url: "http://www.example.com/catalog/#{ID}" }

    assert_response :gone
    assert_empty response.body
  end

  test "a record that is not removed is unaffected" do
    with_records(document) { get "/embed/records/emu-other-1" }

    assert_response :success
  end

  test "lifting the suppression brings the record back" do
    SuppressedRecord.unsuppress!(ID)
    with_records(document(ID)) { get "/embed/records/#{ID}" }

    assert_response :success
    assert_nil SuppressedRecord.solr_filter
  end

  # --- A new way of asking Solr that skips the filter would be a way to show a removed record ---

  test "the app asks Solr only through the client that carries the filter" do
    allowed = { "app/indexers/collections/indexer.rb" => "writes the index (update), reads nothing to show", "app/models/readiness.rb" => "admin/ping only" }
    offenders = Dir[Rails.root.join("{app,lib}/**/*.{rb,erb,rake}")].filter_map do |file|
      relative = Pathname(file).relative_path_from(Rails.root).to_s
      next if allowed.key?(relative) || relative == "lib/suppressed_solr_filter.rb"

      relative if File.read(file).match?(/RSolr\.connect|RSolr::Client\.new|Net::HTTP|Faraday\.new|URI\.open|\bopen-uri\b|Rails\.application\.credentials\.solr|solr_url/)
    end

    assert_empty offenders, "These build their own connection to Solr, which would skip SuppressedSolrFilter: #{offenders.join(', ')}"
  end

  test "every kind of Solr request the app makes goes through RSolr::Client#send_and_receive" do
    assert_includes RSolr::Client.ancestors, SuppressedSolrFilter
    assert_operator RSolr::Client.ancestors.index(SuppressedSolrFilter), :<, RSolr::Client.ancestors.index(RSolr::Client)
  end
end
