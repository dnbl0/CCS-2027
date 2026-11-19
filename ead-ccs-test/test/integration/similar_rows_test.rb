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

  test "a row is a Turbo frame of result cards with its own heading, a description naming the value and a See all link" do
    solr { get "/catalog/emu-source/similar", params: { row: "creator" } }

    assert_response :success
    assert_select "turbo-frame#similar-creator[target=_top] section#similar-creator-section[aria-labelledby=similar-creator-heading]" do
      assert_select "h2#similar-creator-heading", text: "More by this creator"
      assert_select "p", text: /Lees, Derwent/
      assert_select "li.discover-cards__item", count: 2
      assert_select "h3 a[href='/catalog/emu-a']"
      assert_select "a.similar-row__all[href*='f%5Bcreator_ssim%5D%5B%5D=Lees%2C+Derwent']"
    end
    assert_no_match(/emu-withheld|emu-sensitive|withheld-asset/, response.body)
    assert_select "a[href='/catalog/emu-source']", count: 0
  end

  test "each row has its label" do
    { "period" => "From the same period", "place" => "From the same place", "type" => "More of this type" }.each do |row, heading|
      solr { get "/catalog/emu-source/similar", params: { row: row } }
      assert_select "h2#similar-#{row}-heading", text: heading
    end
  end

  test "an empty row is 204, an unknown row is 404, and a withheld record asks for nothing" do
    solr(row: []) { get "/catalog/emu-source/similar", params: { row: "creator" } }
    assert_response :no_content

    solr { get "/catalog/emu-source/similar", params: { row: "colour" } }
    assert_response :not_found

    solr { |seen| get "/catalog/emu-hidden-source/similar", params: { row: "creator" }; assert(seen.none? { |params| params.to_h.key?(:similar_row) }) }
    assert_response :no_content
  end

  test "with tab=1 a row is a panel of More from the collections: at most three cards and See all, no heading (the tab names it)" do
    solr { get "/catalog/emu-source/similar", params: { row: "creator", tab: 1 } }

    assert_response :success
    assert_select "turbo-frame#more-creator[target=_top]" do
      assert_select "h2", count: 0
      assert_operator css_select("li.discover-cards__item").size, :<=, 3
      assert_select "h4 a[href='/catalog/emu-a']"
      assert_select "a.record-arrow-link[href*='f%5Bcreator_ssim%5D%5B%5D=Lees%2C+Derwent']", text: "See all records for Lees, Derwent"
    end
  end

  test "a record the index does not hold is a 404; asked from a lazy frame, the 404 has no body, so the record page is never replaced" do
    with_seeded_menu_cache { with_canned_search(->(_params) { Blacklight::Solr::Response.new({ "response" => { "docs" => [] } }, {}) }) { get "/catalog/emu-gone/similar", params: { row: "creator", tab: 1 }, headers: { "Turbo-Frame" => "more-creator" } } }
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

  test "the record page has Related objects, then one tab with an empty lazy frame per row the record can have" do
    with_seeded_menu_cache do
      with_found_record(source.merge("region_ssim" => nil, "production_place_ssim" => nil)) { get "/catalog/emu-source" }
    end

    assert_response :success
    assert_select "turbo-frame#similar-records[loading=lazy]"
    tabs = css_select("#more-from-the-collections [role=tablist] [role=tab]").map { |tab| tab["id"] }
    assert_equal %w[record-tab-creator record-tab-period record-tab-type], tabs.first(3)
    assert_select "turbo-frame#more-creator[loading=lazy][src='/catalog/emu-source/similar?row=creator&tab=1']"
    assert_select "turbo-frame#more-creator *", count: 0
  end
end
