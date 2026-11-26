require "test_helper"

class SearchUnavailableTest < ActionDispatch::IntegrationTest
  # Solr refusing connections
  def with_solr_down
    original = Blacklight::Solr::Repository.instance_method(:search)
    Blacklight::Solr::Repository.define_method(:search) { |*, **| raise Blacklight::Exceptions::ECONNREFUSED, "connection refused" }
    yield
  ensure
    Blacklight::Solr::Repository.define_method(:search, original)
  end

  test "a search says it is unavailable when Solr cannot be reached, with a 503" do
    with_solr_down { get "/catalog", params: { q: "skull", any_assets: "1" } }

    assert_response :service_unavailable
    assert_select "h1", "Search is unavailable"
    assert_select "a[href='/']"
  end

  test "the JSON API answers 503 too" do
    with_solr_down { get "/catalog.json", params: { q: "skull" } }

    assert_response :service_unavailable
    assert_equal "Search cannot be shown right now. Please try again in a few minutes.", response.parsed_body["error"]
  end

  test "pages that do not search keep working while Solr is down" do
    with_solr_down do
      get "/help"
      assert_response :success

      get "/about"
      assert_response :success
    end
  end
end
