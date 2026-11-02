require "test_helper"

# Delete my data (CCS-148): shown first, removed only by the button, and only the visitor's own rows.
class MyDataTest < ActionDispatch::IntegrationTest
  def save_a_record_and_a_list
    post "/bookmarks", params: { id: "emu-1" }
    post "/lists", params: { list: { name: "Mine" } }
    @user_id = User.order(:id).last.id
    post "/lists/#{List.find_by!(name: 'Mine').id}/items", params: { document_id: "emu-1" }
  end

  def other_visitor
    User.create!.tap do |user|
      user.saved_searches.create!(name: "Theirs", query_params: { q: "x" })
      user.lists.create!(name: "Theirs")
    end
  end

  test "an empty page says there is nothing to delete, and the button is disabled" do
    get "/my_data"

    assert_response :success
    assert_select "h1", "Delete my data"
    assert_select "button[disabled]", text: "Delete my data"
    assert_match "There is nothing to delete", response.body
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "opening the page removes nothing, and it lists what is held" do
    save_a_record_and_a_list
    get "/my_data"

    assert_select "section ul", text: /1 list/
    assert_select "section ul", text: /1 saved record/
    assert_equal 1, List.where(user_id: @user_id).count
    assert_select "button[disabled]", count: 0
  end

  test "the button removes this visitor's rows and the guest user, and no one else's" do
    save_a_record_and_a_list
    other = other_visitor
    search = Search.create!(query_params: { q: "emu" })
    SavedSearch.create!(user_id: @user_id, name: "Mine", query_params: { q: "a" })

    delete "/my_data"

    assert_redirected_to "/my_data"
    assert_equal 0, Bookmark.where(user_id: @user_id).count
    assert_equal 0, List.where(user_id: @user_id).count
    assert_equal 0, ListItem.count
    assert_equal 0, SavedSearch.where(user_id: @user_id).count
    assert_nil User.find_by(id: @user_id)
    assert_equal 1, List.where(user_id: other.id).count
    assert_equal 1, SavedSearch.where(user_id: other.id).count
    assert Search.exists?(search.id), "a search that is not in this visitor's history stays"
    follow_redirect!
    assert_match "Your data has been deleted", response.body
    assert_match "There is nothing to delete", response.body
  end

  test "access requests are not removed, and the page says so" do
    request = AccessRequest.create!(document_id: "emu-1", document_title: "T", request_type: "view", name: "A Person", email: "a@example.org", purpose: "Research")
    get "/my_data"
    assert_match "Requests for access to a record are not removed here", response.body

    delete "/my_data"

    assert AccessRequest.exists?(request.id)
  end

  test "the visitor's search history rows go with the session's list" do
    needs_solr
    get "/catalog?q=emu"
    ids = Array(session[:history])
    assert_not_empty ids

    delete "/my_data"

    assert_equal 0, Search.where(id: ids).count
    assert_empty Array(session[:history])
  end

  test "the page is a 404 while saved records are off, and says noindex, nofollow" do
    get "/my_data"
    assert_match(/\Anoindex, nofollow/, response.headers["X-Robots-Tag"])

    was = Rails.configuration.x.saved_records
    Rails.configuration.x.saved_records = false
    get "/my_data"
    assert_response :not_found
    delete "/my_data"
    assert_response :not_found
  ensure
    Rails.configuration.x.saved_records = was unless was.nil?
  end
end
