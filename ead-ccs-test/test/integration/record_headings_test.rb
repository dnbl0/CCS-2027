require "test_helper"

class RecordHeadingsTest < ActionDispatch::IntegrationTest
  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL"
  end

  test "a record page has exactly one h1, the visible title, and no redundant landmark labels" do
    needs_solr
    get "/catalog", params: { q: "skull", any_assets: "1", format: :json }
    id = JSON.parse(response.body)["data"].first["id"]

    get "/catalog/#{id}"

    assert_response :success
    assert_select "h1", count: 1
    assert_select "h1.record-summary__title", count: 1
    assert_select "h1.visually-hidden", count: 0
    assert_select "section.record-banner[aria-hidden=true]", count: 1
    assert_select "section.record-summary[aria-label]", count: 0
    assert_select "main[aria-label]", count: 0
  end

  test "a record page shows its collection, accession number and UoM ID, with a Copy button (CCS-22)" do
    needs_solr
    get "/catalog/emu-400001"

    assert_response :success
    assert_select ".record-summary__identifier[data-testid=record-identifier]", text: /Grainger Museum Collection, accession number 00\.0001, UoM ID emu-umc-400001/
    assert_select ".record-summary__identifier [data-copy='Grainger Museum Collection, accession number 00.0001, UoM ID emu-umc-400001']"
    assert_select ".record-summary__identifier button[aria-label='Copy collection ID']"
  end
end
