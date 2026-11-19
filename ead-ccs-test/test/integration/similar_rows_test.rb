require "test_helper"
require_relative "../support/discovery_records"
require_relative "../support/request_counter"

# The record page's labelled rows (SimilarRows): each a lazy Turbo frame from /catalog/:id/similar?row=..., a section of the site's
# result cards, or 204 when there is nothing. Solr is stood in for (DiscoveryRecords), with records carrying era and region.
class SimilarRowsIntegrationTest < ActionDispatch::IntegrationTest
  include DiscoveryRecords
  include RequestCounter

  def source = open_record("emu-source", creator_ssim: [ "Lees, Derwent" ], date_era_ssim: [ "20th century" ], region_ssim: [ "Oceania" ],
                                         object_type_ssim: [ "drawing" ])

  def records
    [ source, open_record("emu-a"), open_record("emu-b"), withheld_record("emu-withheld", thumbnail_path_ssi: "/digital-assets/thumbs/withheld-asset.jpg"),
      sensitive_record("emu-sensitive"), withheld_record("emu-hidden-source", creator_ssim: [ "Lees, Derwent" ]) ]
  end

  def solr(row: %w[emu-a emu-withheld emu-sensitive emu-b emu-source], &block)
    with_seeded_menu_cache { with_canned_search(discovery_solr(records: records, row: row), &block) }
  end

  test "each row answers with its own panel frame, leaving out the record, withheld and sensitive ones" do
    %w[creator period type].each do |row|
      solr { get "/catalog/emu-source/similar", params: { row: row } }
      assert_response :success
      assert_select "turbo-frame#more-#{row}[target=_top] li.discover-cards__item", minimum: 1
    end
    assert_no_match(/emu-withheld|emu-sensitive|withheld-asset/, response.body)
    assert_select "a[href='/catalog/emu-source']", count: 0
  end

  test "an empty row is 204, an unknown row is 404, and a withheld record asks for nothing" do
    solr(row: []) { get "/catalog/emu-source/similar", params: { row: "creator" } }
    assert_response :no_content

    solr { get "/catalog/emu-source/similar", params: { row: "colour" } }
    assert_response :not_found

    solr { |seen| get "/catalog/emu-hidden-source/similar", params: { row: "creator" }; assert(seen.none? { |params| params.to_h.key?(:similar_row) }) }
    assert_response :no_content
  end

  test "a row is a panel of More from the collections: at most three cards and See all, no heading (the tab names it)" do
    solr { get "/catalog/emu-source/similar", params: { row: "creator" } }

    assert_response :success
    assert_select "turbo-frame#more-creator[target=_top]" do
      assert_select "h2", count: 0
      assert_operator css_select("li.discover-cards__item").size, :<=, 3
      assert_select "h3 a[href='/catalog/emu-a']"
      assert_select "a.record-arrow-link[href*='f%5Bcreator_ssim%5D%5B%5D=Lees%2C+Derwent']", text: "See all records for Lees, Derwent"
    end
  end

  test "a record the index does not hold is a 404; asked from a lazy frame, the 404 has no body, so the record page is never replaced" do
    with_seeded_menu_cache { with_canned_search(->(_params) { Blacklight::Solr::Response.new({ "response" => { "docs" => [] } }, {}) }) { get "/catalog/emu-gone/similar", params: { row: "creator" }, headers: { "Turbo-Frame" => "more-creator" } } }
    assert_response :not_found
    assert_empty response.body

    with_seeded_menu_cache { with_canned_search(->(_params) { Blacklight::Solr::Response.new({ "response" => { "docs" => [] } }, {}) }) { get "/catalog/emu-gone/similar" } }
    assert_response :not_found
  end

  test "Solr failing leaves the row out" do
    with_seeded_menu_cache do
      with_canned_search(->(_params) { raise Blacklight::Exceptions::ECONNREFUSED, "down" }) { get "/catalog/emu-source/similar", params: { row: "type" } }
    end
    assert_response :no_content
  end

  def with_found_record(document)
    original = Blacklight::Solr::Repository.instance_method(:find)
    Blacklight::Solr::Repository.send(:define_method, :find) do |_id = nil, _params = {}|
      Blacklight::Solr::Response.new({ "response" => { "docs" => [ document ], "numFound" => 1, "start" => 0 } }, {}, document_model: SolrDocument, blacklight_config: blacklight_config)
    end
    yield
  ensure
    Blacklight::Solr::Repository.send(:define_method, :find, original) if original
  end

  test "the record page has Related objects, then one labelled row with an empty lazy frame per way the record can match" do
    with_seeded_menu_cache do
      with_found_record(source.merge("region_ssim" => nil, "production_place_ssim" => nil)) { get "/catalog/emu-source" }
    end

    assert_response :success
    assert_select "turbo-frame#similar-records[loading=lazy]"
    rows = css_select("#more-from-the-collections .record-more__row").map { |row| row["id"] }
    assert_equal %w[more-row-creator more-row-period more-row-type], rows.first(3)
    assert_select "turbo-frame#more-creator[loading=lazy][src='/catalog/emu-source/similar?row=creator']"
    assert_select "turbo-frame#more-creator *", count: 0
  end
end
