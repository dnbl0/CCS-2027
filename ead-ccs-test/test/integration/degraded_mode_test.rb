require "test_helper"
require_relative "../support/outages"

# What the site does when Solr or the database is down (CCS-147, CCS-146): the pages that do not need the failed part keep working,
# the ones that do say so in plain words with Retry-After, and a dead Solr stops being asked. Both are stood in for (Outages).
class DegradedModeTest < ActionDispatch::IntegrationTest
  include Outages

  # A visitor with a guest user, a saved record, a list with a record in it, and a saved search
  def visitor_with_things
    put "/bookmarks/emu-1"
    post "/lists", params: { list: { name: "Violins" } }
    post "/lists/#{List.last.id}/items", params: { document_id: "emu-1" }
    SavedSearch.create!(user: User.find(List.last.user_id), name: "skull", query_params: { "q" => "skull", "any_assets" => "1" })
  end

  test "Solr down: home, Help and About still render" do
    with_solr_down do
      %w[/ /help /about].each do |path|
        get path
        assert_response :success, path
      end
    end
  end

  test "Solr down: the header's collection counts fall back to the last good ones, then to none" do
    store = ActiveSupport::Cache::MemoryStore.new
    original = Rails.cache
    Rails.cache = store
    counts = { [ "collection_ssim", "Grainger Museum Collection" ] => 12 }
    store.write(BrowseMenu::LAST_GOOD_KEY, counts)

    with_solr_down do
      assert_equal counts, BrowseMenu.counts
      store.delete(BrowseMenu::LAST_GOOD_KEY)
      assert_equal({}, BrowseMenu.counts)
    end
  ensure
    Rails.cache = original
  end

  test "Solr down: a search is a 503 with Retry-After and a clear message, and the JSON API too" do
    with_solr_down do
      get "/catalog", params: { q: "skull", any_assets: "1" }
      assert_response :service_unavailable
      assert_equal "30", response.headers["Retry-After"]
      assert_select "h1", "Search is unavailable"

      get "/catalog.json", params: { q: "skull", any_assets: "1" }
      assert_response :service_unavailable
      assert_equal "30", response.headers["Retry-After"]
    end
  end

  test "Solr down: a record page is a 503 too, not a 500" do
    with_solr_down { get "/catalog/emu-1" }

    assert_response :service_unavailable
  end

  test "Solr down: lists, a list (its records named by id), saved searches and the search history still render" do
    visitor_with_things

    with_solr_down do
      get "/lists"
      assert_response :success
      assert_select "a[href='/lists/#{List.last.id}']"

      get "/lists/#{List.last.id}"
      assert_response :success
      assert_select "h1", "Violins"
      assert_select "[role=status]", text: /search is unavailable/
      assert_select "[role=status] a[href='/catalog/emu-1']", text: "emu-1"
      assert_equal "30", response.headers["Retry-After"]

      get "/saved_searches"
      assert_response :success
      assert_select "a", text: /skull/

      get "/search_history"
      assert_response :success
    end
  end

  test "Solr down: after a few failures Solr is not asked at all, so threads are not held" do
    with_solr_down do
      12.times { get "/catalog", params: { q: "skull", any_assets: "1" } }
      asked = Outages::SolrDown.requests
      5.times { get "/catalog", params: { q: "skull", any_assets: "1" } }

      assert_equal asked, Outages::SolrDown.requests
      assert_equal :open, SolrGuard.breaker.state
      assert_response :service_unavailable
    end
  end

  test "database down: Help, About and home still render for a visitor with a saved record (the header's count says 0)" do
    visitor_with_things

    with_database_down do
      %w[/ /help /about].each do |path|
        get path
        assert_response :success, path
      end
    end
  end

  test "database down: a page that needs it is a friendly 503 page in the site chrome, with Retry-After and no detail" do
    visitor_with_things

    with_database_down do
      as_production { get "/lists" }
    end

    assert_response :service_unavailable
    assert_equal "30", response.headers["Retry-After"]
    assert_select ".site-header"
    assert_select ".page-banner h1", "The service is busy or unavailable"
    assert_select ".error-page__links a", text: "Try this page again"
    assert_no_match(/ConnectionNotEstablished|database is down|backtrace|PG::/i, response.body)
  end

  test "database down: a write (Save a record) is a 503, not a 500, and nothing is half-saved" do
    put "/bookmarks/emu-1"

    with_database_down do
      as_production { put "/bookmarks/emu-2" }
    end

    assert_response :service_unavailable
    assert_equal [ "emu-1" ], Bookmark.pluck(:document_id)
  end
end
