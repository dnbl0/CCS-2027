require "test_helper"
require_relative "../support/outages"

# A double click, a second tab or a client retry sends the same write twice, or two at once (CCS-147). None may make a duplicate or
# end in an error (a unique index refusing the second must not become a 500).
class DoubleSubmitTest < ActionDispatch::IntegrationTest
  include Outages

  test "Save a record twice: one bookmark" do
    assert_difference "Bookmark.count", 1 do
      2.times { put "/bookmarks/emu-1" }
    end
    assert_response :redirect
  end

  test "Create list twice: one list, and both requests end on it" do
    assert_difference "List.count", 1 do
      2.times { post "/lists", params: { list: { name: "Violins" } } }
    end

    assert_redirected_to "/lists/#{List.last.id}"
  end

  test "Create list from a record twice: one list, the record in it once" do
    assert_difference [ "List.count", "ListItem.count" ], 1 do
      2.times { post "/lists", params: { list: { name: "Violins" }, document_id: "emu-1" } }
    end
    assert_response :redirect
  end

  test "Add to list twice: one item, and a notice that it is already there" do
    post "/lists", params: { list: { name: "Violins" } }
    list = List.last

    assert_difference "ListItem.count", 1 do
      2.times { post "/lists/#{list.id}/items", params: { document_id: "emu-1" } }
    end
    follow_redirect!
    assert_select ".alert, [role=status]", text: /already in/
  end

  test "two Add to list requests at once, the unique index refuses the second: a notice, not an error" do
    post "/lists", params: { list: { name: "Violins" } }
    list = List.last
    # The check in the model passes (it sees no item yet), the index then refuses the insert
    ListItem.create!(list: list, document_id: "emu-1")
    original = ListItem.instance_method(:valid?)
    ListItem.define_method(:valid?) { |*| true }
    begin
      assert_no_difference "ListItem.count" do
        post "/lists/#{list.id}/items", params: { document_id: "emu-1" }
      end
    ensure
      ListItem.define_method(:valid?, original)
    end

    assert_response :redirect
    follow_redirect!
    assert_select ".alert, [role=status]", text: /already in/
  end

  test "Create list: two at once, the unique index refuses the second: it finds the first's list" do
    post "/lists", params: { list: { name: "Violins" } }
    first = List.last
    original = List.instance_method(:valid?)
    List.define_method(:valid?) { |*| true } # skip the model's check so the database index decides
    begin
      assert_no_difference "List.count" do
        post "/lists", params: { list: { name: "violins" } }
      end
    ensure
      List.define_method(:valid?, original)
    end

    assert_redirected_to "/lists/#{first.id}"
  end

  test "a list's name made again later is still refused, with the reason" do
    post "/lists", params: { list: { name: "Violins" } }

    travel(List::DOUBLE_SUBMIT_SECONDS + 1) { post "/lists", params: { list: { name: "Violins" } } }

    assert_response :unprocessable_content
  end

  test "Save a search twice: one saved search" do
    get "/catalog", params: { q: "skull", any_assets: "1" }
    search = Search.last

    assert_difference "SavedSearch.count", 1 do
      2.times { post "/saved_searches", params: { search_id: search.id } }
    end
  end

  test "SavedSearch.keep makes a search once however often it is asked, even with the same params in another key order" do
    user = User.create!
    params = { "q" => "skull", "f" => { "collection_ssim" => [ "Grainger Museum Collection" ] } }

    assert_difference "SavedSearch.count", 1 do
      3.times { SavedSearch.keep(user, name: "skull", query_params: params) }
    end
    assert_no_difference("SavedSearch.count") { SavedSearch.keep(user, name: "skull", query_params: params.reverse_each.to_h) }
  end

  test "a visitor keeps at most MAX_PER_USER saved searches" do
    user = User.create!
    SavedSearch::MAX_PER_USER.times { |n| SavedSearch.keep(user, name: "search #{n}", query_params: { "q" => n.to_s }) }

    saved = SavedSearch.keep(user, name: "one too many", query_params: { "q" => "x" })

    assert_not saved.persisted?
    assert_match(/at most #{SavedSearch::MAX_PER_USER}/, saved.errors.full_messages.to_sentence)
  end

  test "Save a record is refused over MAX_SAVED, with the reason" do
    put "/bookmarks/emu-1"
    user = User.find(Bookmark.last.user_id)
    limit = BookmarksController::MAX_SAVED
    BookmarksController.send(:remove_const, :MAX_SAVED)
    BookmarksController.const_set(:MAX_SAVED, 1)
    begin
      assert_no_difference "Bookmark.count" do
        put "/bookmarks/emu-2"
      end
    ensure
      BookmarksController.send(:remove_const, :MAX_SAVED)
      BookmarksController.const_set(:MAX_SAVED, limit)
    end

    assert_response :redirect
    assert_equal [ "emu-1" ], user.bookmarks.pluck(:document_id)
  end

  test "an Access request sent twice: one request, and the same confirmation" do
    attributes = { document_id: "emu-9044", document_title: "T", request_type: "view", name: "Test Person", email: "test.person@example.invalid", purpose: "Fake research purpose" }

    first = AccessRequest.submit(attributes)
    second = nil
    assert_no_difference "AccessRequest.count" do
      second = AccessRequest.submit(attributes.merge(email: "TEST.person@example.invalid"))
    end

    assert first.persisted?
    assert_equal first.id, second.id
  end

  test "an Access request is made again after the double-submit window, or for another record" do
    attributes = { document_id: "emu-9044", document_title: "T", request_type: "view", name: "Test Person", email: "test.person@example.invalid", purpose: "Fake research purpose" }
    AccessRequest.submit(attributes)

    assert_difference "AccessRequest.count", 1 do
      travel(AccessRequest::DOUBLE_SUBMIT_SECONDS + 1) { AccessRequest.submit(attributes) }
    end
    assert_difference "AccessRequest.count", 1 do
      AccessRequest.submit(attributes.merge(document_id: "emu-1"))
    end
  end

  test "an invalid Access request is returned with its errors, saved nowhere" do
    request = AccessRequest.submit(document_id: "emu-1", document_title: "T", request_type: "view", name: "", email: "nope", purpose: "")

    assert_not request.persisted?
    assert request.errors[:name].any?
  end
end
