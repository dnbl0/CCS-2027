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

  test "each search in the history has a Save button naming the search" do
    search_id_for("skull")

    get "/search_history"

    assert_select "td.save-search form[action='/saved_searches?search_id=#{Search.last.id}'] button", text: "Save this search"
    assert_select "td.save-search button[aria-label*='skull']"
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
