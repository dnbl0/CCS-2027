require "test_helper"

# CCS-130: a visitor keeps searches from their search history. The owner is the guest user of the session cookie,
# created on the first save, as for saved records.
class SavedSearchesTest < ActionDispatch::IntegrationTest
  def search_id_for(query)
    get "/catalog", params: { q: query }
    Search.order(:id).last.id
  end

  test "the page is empty, and creates no guest, until a search is saved" do
    assert_no_difference "User.count" do
      get "/saved_searches"
    end

    assert_response :success
    assert_select ".saved-empty__text", text: /not saved any searches/
  end

  test "each search in the history has Save, Share and Delete icon buttons, named for their search" do
    search_id_for("skull")

    get "/search_history"

    assert_select "th.history-actions-heading", text: "Actions"
    assert_select "td.history-actions form[action='/saved_searches?search_id=#{Search.last.id}'] button.history-action" do
      assert_select "svg[aria-hidden=true]"
      assert_select ".visually-hidden", text: "Save search: skull"
      assert_select "[data-action-tooltip-text=Save]"
    end
    assert_select "td.history-actions button[data-clipboard-target=button] .visually-hidden", text: "Share search: skull"
    assert_select "td.history-actions button[data-action-tooltip-text=Share]"
    assert_select "td.history-actions form[action='/search_history/#{Search.last.id}'] button .visually-hidden", text: "Delete search: skull"
    assert_select "td.history-actions button[data-action-tooltip-text=Delete]"
  end

  test "Delete takes one search out of the history and leaves the others" do
    keep = search_id_for("violin")
    drop = search_id_for("skull")

    delete "/search_history/#{drop}"
    follow_redirect!

    assert_select "td.query", text: /violin/
    assert_select "td.query", text: /skull/, count: 0
    assert Search.exists?(keep)
  end

  test "Delete also takes out the unfiltered search the default-filter redirect left behind" do
    get "/catalog", params: { q: "skull" }
    follow_redirect!
    assert_equal 2, Search.count

    delete "/search_history/#{session[:history].first}"
    follow_redirect!

    assert_equal [], session[:history]
    assert_select "td.query", count: 0
  end

  test "Delete does nothing to a search that is not in the visitor's own history" do
    other = Search.create!(query_params: { "q" => "violin" })

    delete "/search_history/#{other.id}"

    assert_redirected_to "/search_history"
    assert Search.exists?(other.id)
  end

  test "saving a search from the history lists it, and opening it repeats the search" do
    id = search_id_for("skull")

    assert_difference [ "User.count", "SavedSearch.count" ], 1 do
      post "/saved_searches", params: { search_id: id }
    end
    follow_redirect!

    assert_response :success
    assert_select ".saved-searches__flash", text: "Search saved."
    assert_select "table.saved-searches td.saved-searches__name a[href*='q=skull']"
  end

  test "a search that is not in the visitor's own history cannot be saved" do
    other = Search.create!(query_params: { "q" => "violin" })

    assert_no_difference "SavedSearch.count" do
      post "/saved_searches", params: { search_id: other.id }
    end

    assert_redirected_to "/search_history"
  end

  test "a saved search can be removed, and only by its owner" do
    post "/saved_searches", params: { search_id: search_id_for("skull") }
    saved = SavedSearch.last

    stranger = SavedSearch.create!(user: User.create!, name: "Not mine", query_params: { "q" => "x" })
    delete "/saved_searches/#{stranger.id}"
    assert SavedSearch.exists?(stranger.id)

    delete "/saved_searches/#{saved.id}"
    assert_not SavedSearch.exists?(saved.id)
  end

  test "saved searches are kept after the search history is cleared" do
    post "/saved_searches", params: { search_id: search_id_for("skull") }

    delete "/search_history/clear"
    get "/saved_searches"

    assert_select "table.saved-searches td.saved-searches__name", count: 1
  end
end
