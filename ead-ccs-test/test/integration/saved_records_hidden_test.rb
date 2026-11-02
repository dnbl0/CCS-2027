require "test_helper"

# Saved records are off by default (config.x.saved_records in config/application.rb): no Save buttons, no saved bar, no saved
# list. The test environment turns them on for the rest of the suite, so these tests switch them off for one example.
class SavedRecordsHiddenTest < ActionDispatch::IntegrationTest
  setup do
    @was = Rails.configuration.x.saved_records
    Rails.configuration.x.saved_records = false
  end

  teardown { Rails.configuration.x.saved_records = @was }

  # The results and record pages read the Solr core at SOLR_URL. The "rails" CI job has no Solr, so these tests skip themselves
  # when it cannot be reached.
  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL"
  end

  def assert_no_saving
    assert_response :success
    assert_select ".site-nav__saved", count: 0
    assert_select ".site-nav__saved-item", count: 0
    assert_select "[data-role=bookmark-counter]", count: 0
    assert_select ".bookmark-toggle, .result-card__save, .record-summary__save", count: 0
    assert_select "a[href='/bookmarks']", count: 0
    assert_select ".list-menu, a[href='/lists']", count: 0
  end

  test "the content pages show no saved bar" do
    [ "/", "/help", "/about" ].each do |path|
      get path

      assert_no_saving
    end
  end

  test "the results and record pages show no saved bar or Save button" do
    needs_solr
    get "/catalog", params: { q: "skull", any_assets: "1" }
    assert_no_saving

    get "/catalog", params: { q: "skull", any_assets: "1", format: :json }
    id = JSON.parse(response.body)["data"].first["id"]
    get "/catalog/#{id}"
    assert_no_saving
  end

  test "the saved list and its requests are a 404" do
    get "/bookmarks"
    assert_response :not_found

    post "/bookmarks", params: { id: "x" }
    assert_response :not_found

    delete "/bookmarks/clear"
    assert_response :not_found
  end

  test "the named lists and their requests are a 404" do
    get "/lists"
    assert_response :not_found
    get "/lists/new"
    assert_response :not_found
    post "/lists", params: { list: { name: "Violins" } }
    assert_response :not_found
    post "/lists/1/items", params: { document_id: "x" }
    assert_response :not_found
    delete "/lists/1"
    assert_response :not_found
  end

  test "the stock record pages do not offer to save the record" do
    needs_solr
    get "/stock/emu-9044"

    assert_no_saving
  end
end
