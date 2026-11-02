require "test_helper"

# CCS-143 uses Blacklight's own search history (searches saved in the session, the /search_history page with its
# recent-searches table and Clear history button). CCS-206 only adds the grouping by day: app/views/search_history/index.html.erb.
class SearchHistoryTest < ActionDispatch::IntegrationTest
  test "searches are saved and listed on Blacklight's own history page, newest first" do
    get "/catalog", params: { q: "skull" }
    get "/catalog", params: { q: "violin" }

    get "/search_history"

    assert_response :success
    assert_select "h1.page-heading", "Search History"
    assert_select "table.search-history td.query a", count: 2
    assert_select "table.search-history tr:first-child td.query", text: /violin/
    assert_select "a[data-turbo-method=delete]", text: "Clear Search History"
    assert_select ".search-history-day h3", count: 1, text: "Today"
  end

  test "searches from earlier days are listed under their own day, newest day first" do
    get "/catalog", params: { q: "skull" }
    Search.update_all(created_at: 2.days.ago)
    get "/catalog", params: { q: "violin" }

    get "/search_history"

    assert_select ".search-history-day h3", count: 2
    assert_select ".search-history-day:first-of-type h3", text: "Today"
    assert_select ".search-history-day:first-of-type td.query", text: /violin/
    assert_select ".search-history-day:last-of-type td.query", text: /skull/
  end

  test "a visitor with no searches is told so" do
    get "/search_history"

    assert_select "h2.section-heading", text: /no search history/i
    assert_select ".search-history-day", count: 0
  end
end
