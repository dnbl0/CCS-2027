require "test_helper"

# ?layout=viewer: the same record address, another layout, off by default; the plain address stays the canonical one and the variant is
# kept out of search results.
class RecordViewerLayoutIntegrationTest < ActionDispatch::IntegrationTest
  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL"
  end

  test "the viewer layout is off unless asked for, and is on for ?layout=viewer" do
    needs_solr
    get "/catalog/emu-406126"
    assert_response :success
    assert_select ".viewer-page", false
    assert_select ".record-hero"

    get "/catalog/emu-406126", params: { layout: "viewer" }
    assert_response :success
    assert_select ".viewer-page"
    assert_select ".record-hero", false
    assert_select "h1", 1
    assert_select "link[rel=canonical][href$='/catalog/emu-406126']"
  end

  test "an unknown layout value is the plain page" do
    needs_solr
    get "/catalog/emu-406126", params: { layout: "nonsense" }
    assert_select ".viewer-page", false
  end

  test "the variant is noindex, the plain address is not touched" do
    assert_match(/noindex/, RobotsPolicy.directive("/catalog/emu-1", { "layout" => "viewer" }, indexing: true))
    assert_no_match(/noindex/, RobotsPolicy.directive("/catalog/emu-1", {}, indexing: true).to_s)
  end
end
