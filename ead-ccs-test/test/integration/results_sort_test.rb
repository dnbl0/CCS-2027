# frozen_string_literal: true

require "test_helper"
require_relative "../support/discovery_records"

# Records with a digital asset come first in the results unless the visitor sorts by title (a filter with no search words scores every record the same)
class ResultsSortTest < ActionDispatch::IntegrationTest
  include DiscoveryRecords

  test "relevance and the date sorts put records with a digital asset before those without, then A to Z" do
    fields = CatalogController.blacklight_config.sort_fields

    %w[relevance date-desc date-asc].each do |key|
      assert_match(/has_digital_asset_bsi desc, title_si asc\z/, fields[key].sort, key)
    end
    assert_equal "title_si asc", fields["title"].sort
    assert_equal "title_si desc", fields["title-desc"].sort
  end

  test "the results request asks Solr for that order by default" do
    seen = nil
    with_canned_search(->(params) { (seen ||= params) && canned_response([ open_record("a") ]) }) { |_requests| get "/catalog", params: { any_assets: "1", search_field: "all_fields" } }

    assert_response :success
    assert_match(/has_digital_asset_bsi desc/, seen[:sort].to_s)
  end
end
