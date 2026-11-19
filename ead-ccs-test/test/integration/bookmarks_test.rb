require "test_helper"

# Saving records uses Blacklight's own bookmarks (BookmarksController, the Bookmark model, current_or_guest_user) with
# a guest per session cookie: visitors never log in. See app/controllers/concerns/guest_bookmarks.rb.
class BookmarksTest < ActionDispatch::IntegrationTest
  # These tests read records from the Solr core at SOLR_URL. The "rails" CI job has no Solr (the system tests, which
  # do, cover the same flow in a browser), so they skip themselves when it cannot be reached.
  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL"
  end

  # Two records from the Solr core at SOLR_URL
  def record_ids
    @record_ids ||= begin
      get "/catalog", params: { q: "skull", any_assets: "1", format: :json }
      JSON.parse(response.body)["data"].first(2).map { |doc| doc["id"] }
    end
  end

  def saved_bar_count
    css_select(".site-nav__saved [data-role=bookmark-counter]").first.text.to_i
  end

  test "browsing creates no guest user and the saved bar says 0 saved records" do
    assert_no_difference "User.count" do
      get "/catalog", params: { q: "skull", any_assets: "1" }
      get "/"
    end

    assert_select "a.site-nav__saved--empty[href='/bookmarks']", text: /0\s+saved records/
  end

  test "the saved bar is in the breadcrumb strip of the results page and the saved list, with aria-current on the list" do
    get "/catalog", params: { q: "skull", any_assets: "1" }
    assert_select ".breadcrumb-strip > a.site-nav__saved[href='/bookmarks']", count: 1
    assert_select ".site-header a.site-nav__saved", count: 0
    assert_select "a.site-nav__saved[aria-current]", count: 0

    get "/bookmarks"
    assert_select ".breadcrumb-strip > a.site-nav__saved[href='/bookmarks'][aria-current=page]", count: 1

    get "/about"
    assert_select ".breadcrumb-strip > a.site-nav__saved", count: 1
    assert_select ".site-header a.site-nav__saved", count: 0
  end

  test "the saved list is empty, without a login redirect, for a new visitor" do
    needs_solr
    get "/bookmarks"

    assert_response :success
    assert_select "h1", text: "Saved records"
    assert_select ".saved-empty", text: /You have not saved any records yet/
    assert_equal 0, User.count
  end

  test "saving a record creates one guest, shows Saved and counts it, and removing it empties the list" do
    needs_solr
    id = record_ids.first

    assert_difference [ "User.count", "Bookmark.count" ], 1 do
      put "/bookmarks/#{id}", xhr: true, headers: { "Accept" => "application/json" }
    end
    assert_response :success
    assert_equal 1, JSON.parse(response.body).dig("bookmarks", "count")

    get "/catalog", params: { q: "skull", any_assets: "1" }
    assert_equal 1, saved_bar_count
    assert_select ".site-nav__saved .site-nav__saved-text", text: /1\s+saved record\b/
    assert_select ".result-card[data-document-id='#{id.parameterize}'] form.save-control" do
      assert_select "input[type=hidden][name=_method][value=delete]"
      assert_select ".toggle-bookmark-label.checked", text: /Saved/
    end
    assert_select ".result-card:not([data-document-id='#{id.parameterize}']) .toggle-bookmark-label.checked", count: 0

    get "/bookmarks"
    assert_select ".page-banner h1", text: "Saved records"
    assert_select ".saved-main .result-card", count: 1
    assert_select ".saved-toolbar__count", text: "1 saved record"

    assert_no_difference "User.count" do
      delete "/bookmarks/#{id}", xhr: true, headers: { "Accept" => "application/json" }
    end
    assert_equal 0, JSON.parse(response.body).dig("bookmarks", "count")
    get "/bookmarks"
    assert_select ".saved-empty"
  end

  test "each control has an accessible name that includes the record title" do
    needs_solr
    get "/catalog", params: { q: "skull", any_assets: "1" }

    assert_select ".result-card form.save-control .toggle-bookmark-label .visually-hidden", text: /record: \S/, minimum: 1
    assert_select ".result-card input.save-control__input[type=checkbox]", minimum: 1
  end

  test "the record page has the control and the counted bar" do
    needs_solr
    id = record_ids.first
    put "/bookmarks/#{id}", xhr: true, headers: { "Accept" => "application/json" }

    get "/catalog/#{id}"

    assert_response :success
    assert_select ".record-actions__row form.save-control .toggle-bookmark-label.checked"
    assert_equal 1, saved_bar_count
  end

  test "bookmarks are per visitor and last as long as the 30-day session cookie" do
    needs_solr
    put "/bookmarks/#{record_ids.first}", xhr: true, headers: { "Accept" => "application/json" }
    cookie = response.headers["Set-Cookie"].to_s
    expires = Time.httpdate(cookie[/expires=([^;]+)/i, 1])
    assert_in_delta 30.days.from_now.to_f, expires.to_f, 1.day.to_f

    other = open_session
    other.get "/bookmarks"
    other.assert_select ".saved-empty"
  end

  test "clearing removes every saved record" do
    needs_solr
    record_ids.each { |id| put "/bookmarks/#{id}", xhr: true, headers: { "Accept" => "application/json" } }
    assert_equal 2, Bookmark.count

    delete "/bookmarks/clear"

    assert_redirected_to "/bookmarks"
    assert_equal 0, Bookmark.count
  end
end
