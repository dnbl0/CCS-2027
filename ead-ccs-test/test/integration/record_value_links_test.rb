require "test_helper"
require_relative "../support/discovery_records"

# The record page's values as ways sideways (Blacklight's link_to_facet idea): each value of creator, object type, classification,
# material, place, subject, era, region, collection and named collection opens the search filtered to it (or, for creator, place
# and subject, the value's browse page where there is one). Free text stays text. A stubbed record carries the fields a local
# core may lack (era, region).
class RecordValueLinksTest < ActionDispatch::IntegrationTest
  include DiscoveryRecords

  RECORD = {
    "id" => "emu-links", "title_tsim" => [ "Study of a hand" ], "format" => [ "Image" ], "object_type_ssim" => [ "drawing" ],
    "classification_ssim" => [ "Fine Art" ], "material_ssim" => [ "pencil on paper" ], "named_collection_ssim" => [ "Lees bequest" ],
    "collection_ssim" => [ "University Art Collection" ], "date_era_ssim" => [ "20th century" ], "region_ssim" => [ "Oceania", "Europe" ],
    "subject_ssim" => [ "hands" ], "creator_ssim" => [ "Lees, Derwent" ], "creator_display_ssim" => [ "Lees, Derwent (1884 - 1931) Artist" ],
    "production_place_ssim" => [ "London" ], "description_tsim" => [ "A careful study of a hand." ], "licence_type_ssim" => [ "Public domain - Copyright expired" ]
  }.freeze

  def with_found_record(document)
    original = Blacklight::Solr::Repository.instance_method(:find)
    Blacklight::Solr::Repository.send(:define_method, :find) do |_id = nil, _params = {}|
      Blacklight::Solr::Response.new({ "response" => { "docs" => [ document ], "numFound" => 1, "start" => 0 } }, {}, document_model: SolrDocument, blacklight_config: blacklight_config)
    end
    yield
  ensure
    Blacklight::Solr::Repository.send(:define_method, :find, original) if original
  end

  def record_page(document = RECORD)
    with_seeded_menu_cache { with_found_record(document) { get "/catalog/#{document['id']}" } }
    assert_response :success
  end

  def filter_link(field, value) = "a[href*='#{CGI.escape("f[#{field}][]")}=#{CGI.escape(value)}']"

  test "object type, classification, material and named collection in the details link to their filtered search" do
    record_page

    assert_select ".record-facts__list" do
      { "object_type_ssim" => "drawing", "classification_ssim" => "Fine Art", "material_ssim" => "pencil on paper",
        "named_collection_ssim" => "Lees bequest" }.each do |field, value|
        assert_select filter_link(field, value), text: value
      end
    end
  end

  test "creator, place and subject still open their browse pages; the description is not a link" do
    record_page

    assert_select ".record-facts__list a[href^='/browse/makers/']", text: /Lees, Derwent/
    assert_select ".record-facts__list a[href^='/browse/places/']", text: "London"
    assert_select ".record-facts__list a[href^='/browse/subjects/']", text: "hands"
    assert_select ".record-facts__list a", text: /careful study/, count: 0
  end

  test "era and region are rows of terms in Object details, each value its own filtered search" do
    record_page

    assert_select ".record-facts__list ul.record-terms" do
      assert_select filter_link("date_era_ssim", "20th century"), text: "20th century"
      assert_select filter_link("region_ssim", "Oceania"), text: "Oceania"
      assert_select filter_link("region_ssim", "Europe"), text: "Europe"
    end
  end

  test "a record without era or region has no such tags, and nothing breaks" do
    record_page(RECORD.except("date_era_ssim", "region_ssim"))

    assert_select "a[href*='date_era_ssim'], a[href*='region_ssim']", count: 0
  end
end
