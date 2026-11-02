require "test_helper"

# CCS-149: characterisation tests for SearchService, which adds two behaviours to Blacklight's search (the spelling retry and the count of
# what the filters hide). They read the real index, so they skip when no Solr answers (needs_solr).
class SearchServiceTest < ActionDispatch::IntegrationTest
  setup { needs_solr }

  test "a misspelt search that finds nothing is run again with Solr's correction, and the page says so" do
    get "/catalog", params: { q: "anatommy", search_field: "all_fields", any_assets: "1" }

    assert_response :success
    assert_select ".spelling-correction", /No results for\s+anatommy/
    assert_select ".spelling-correction", /Showing results for\s+anatomy/
    assert_select "#documents .document, #documents article", minimum: 1
  end

  test "a correctly spelt search is left alone" do
    get "/catalog", params: { q: "anatomy", search_field: "all_fields", any_assets: "1" }

    assert_response :success
    assert_select ".spelling-correction", count: 0
  end

  test "an empty page caused by its filters links to the same search without them" do
    get "/catalog", params: { q: "microscope", search_field: "all_fields", any_assets: "1", f: { collection_ssim: [ "Grainger Museum Collection" ] } }

    assert_response :success
    assert_select ".results-empty__unfiltered", /\d/
    assert_select ".results-empty__button"
  end

  test "an empty page that no filter explains offers a new search, not a count" do
    get "/catalog", params: { q: "zzzqxvjkw", search_field: "all_fields", any_assets: "1" }

    assert_response :success
    assert_select ".results-empty__unfiltered", count: 0
    assert_select ".results-empty__new-search"
  end
end
