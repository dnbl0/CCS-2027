# frozen_string_literal: true

require "test_helper"

# The record page's "Related objects" and "Recently viewed" tiles: more to look at without searching again (as Google Arts &
# Culture and Europeana offer). They need the Solr core, so they skip where there is none (the "rails" CI job).
class RecordRelatedTest < ActionDispatch::IntegrationTest
  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    needs_solr # after the cache is saved: a skip still runs the teardown
  end

  teardown { Rails.cache = @cache }

  def records_of_one_type
    response = Blacklight.default_index.connection.get("select", params: { q: "object_type_ssim:*", fl: "id,object_type_ssim", rows: 400 })
    response.dig("response", "docs").group_by { |doc| doc["object_type_ssim"].first }.values.find { |docs| docs.size >= 3 }
  end

  def path_for(doc) = "/catalog/#{ERB::Util.url_encode(doc['id'])}"

  # The showcase record page has one "Similar objects" section (a lazy frame, image-only) in place of Related objects and Recently
  # viewed; the recently viewed list is still kept for My data.
  test "a record page has the Similar objects frame, and no Related objects or Recently viewed sections" do
    first, second = records_of_one_type

    get path_for(first)
    get path_for(second)

    assert_response :success
    assert_select "turbo-frame#similar-records[src][loading=lazy]"
    assert_select "section#related-objects", count: 0
    assert_select "section#recently-viewed", count: 0
  end

  test "reloading a record does not list it beside itself" do
    first, = records_of_one_type

    2.times { get path_for(first) }

    assert_select "section#recently-viewed", count: 0
  end

  test "Delete my data empties the recently viewed list, and My data lists it first" do
    first, second = records_of_one_type
    get path_for(first)
    get path_for(second)

    get "/my-data"
    assert_select "section ul", text: /2 records in your recently viewed list/

    delete "/my-data"
    get path_for(second)
    assert_select "section#recently-viewed", count: 0
  end

  test "the lists are for this visitor only: a page is not shared between visitors" do
    first, second = records_of_one_type
    get path_for(first)
    get path_for(second)

    assert_no_match(/public/, response.headers["Cache-Control"].to_s)
    open_session do |other|
      other.get path_for(second)
      other.assert_select "section#recently-viewed", count: 0
    end
  end
end
