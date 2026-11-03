require "test_helper"
require_relative "../support/canned_search"
require_relative "../support/request_counter"
require_relative "../support/env_override"
require_relative "../support/stub_records"

# Galleries: a list shared by an unguessable link, the public read-only page, and "Add to my list". The records come from a
# canned Solr answer, so these run in the CI job that has no Solr; the last tests use the real core.
class GalleriesTest < ActionDispatch::IntegrationTest
  include CannedSearch
  include RequestCounter
  include EnvOverride
  include StubRecords

  THUMBS = "/digital-assets/thumbs/".freeze

  def doc(id, licence: "Public domain - Copyright expired", **extra)
    { "id" => id, "title_tsim" => [ "Title #{id}" ], "creator_ssim" => [ "Maker #{id}" ], "collection_ssim" => [ "Grainger Museum Collection" ],
      "licence_type_ssim" => [ licence ], "thumbnail_path_ssi" => "#{THUMBS}#{id}.jpg" }.merge(extra)
  end

  DOCS = [
    ->(t) { t.doc("open-1") },
    ->(t) { t.doc("withheld-1", licence: "ICIP Rights") },
    ->(t) { t.doc("sensitive-1", restrictions_tsi: [ "Culturally sensitive images" ]) },
    ->(t) { t.doc("open-2") }
  ].freeze

  def docs = DOCS.map { |build| build.call(self) }

  # The owner's list of the ids given, shared. Returns the list.
  def shared_list(ids = %w[open-1 withheld-1 sensitive-1 open-2 gone-1], name: "Strings", description: "Instruments we like")
    post "/lists", params: { list: { name: name, description: description } }
    list = List.order(:id).last
    ids.each { |id| post "/lists/#{list.id}/items", params: { document_id: id } }
    post "/lists/#{list.id}/share"
    list.reload
  end

  def as_new_visitor = reset!

  def view_gallery(list, &block)
    with_seeded_menu_cache do
      with_canned_search(canned_response(docs)) { get "/galleries/#{list.share_token}" }
    end
    block&.call
  end

  # --- Sharing, as the owner ---

  test "sharing creates a link, goes back to the list with the dialog open, and the page says anyone with the link can see it" do
    post "/lists", params: { list: { name: "Strings" } }
    list = List.last
    assert_nil list.share_token

    post "/lists/#{list.id}/share"
    assert_redirected_to "/lists/#{list.id}?share=1"
    list.reload
    assert list.shared?
    follow_redirect!

    assert_select "[data-dialog-open-on-connect-value=true]"
    assert_select "dialog.share__dialog input[readonly][value$='/galleries/#{list.share_token}']"
    assert_select ".share-status", text: /Shared\. Anyone with the link can see this list/
    assert_select "dialog .share__note", text: /Anyone with the link can see this list/
    assert_select "dialog button", text: "Stop sharing"
    assert_select "dialog button", text: "Make a new link"
  end

  test "the share dialog is not open on a list page opened the ordinary way, and a list not shared has a button to share it" do
    post "/lists", params: { list: { name: "Strings" } }
    get "/lists/#{List.last.id}"

    assert_select "[data-dialog-open-on-connect-value]", count: 0
    assert_select ".share-status", count: 0
    assert_select "dialog button", text: "Create share link"
    assert_select "dialog input[readonly]", count: 0
  end

  test "a new link replaces the old: the old is a 404, the new works" do
    list = shared_list
    old = list.share_token
    post "/lists/#{list.id}/share/regenerate"

    assert_not_equal old, list.reload.share_token
    get "/galleries/#{old}"
    assert_response :not_found
    view_gallery(list)
    assert_response :success
  end

  test "stopping sharing makes the link a 404" do
    list = shared_list
    token = list.share_token

    delete "/lists/#{list.id}/share"
    assert_redirected_to "/lists/#{list.id}"
    assert_nil list.reload.share_token

    get "/galleries/#{token}"
    assert_response :not_found
  end

  test "only the owner can share, replace or stop: another visitor is told the list is not found, and nothing changes" do
    list = shared_list
    token = list.share_token
    as_new_visitor

    post "/lists/#{list.id}/share/regenerate"
    assert_redirected_to "/lists"
    delete "/lists/#{list.id}/share"
    assert_equal token, list.reload.share_token

    other = User.create!.lists.create!(name: "Unshared")
    post "/lists/#{other.id}/share"
    assert_nil other.reload.share_token
  end

  test "deleting the list revokes the link" do
    list = shared_list
    token = list.share_token
    delete "/lists/#{list.id}"

    get "/galleries/#{token}"
    assert_response :not_found
  end

  test "Delete my data revokes the link, and its page counts the shared lists" do
    list = shared_list
    token = list.share_token
    get "/my_data"
    assert_select "section ul", text: /1 list shared by a link/

    delete "/my_data"
    get "/galleries/#{token}"
    assert_response :not_found
  end

  # --- The public page ---

  test "a wrong, malformed or revoked token is a 404, and says nothing of which" do
    shared_list
    as_new_visitor
    [ "a" * 32, "short", "#{'a' * 31}!", "a" * 33 ].each do |token|
      get "/galleries/#{token}"
      assert_response :not_found, token
      assert_not_includes response.body, "Strings"
    end
  end

  test "the gallery shows the title, description and the records as result cards in the owner's order, and nothing of the owner" do
    list = shared_list(%w[open-1 open-2])
    owner = User.find(list.user_id)
    as_new_visitor

    with_seeded_menu_cache { with_canned_search(canned_response(docs)) { get "/galleries/#{list.share_token}" } }

    assert_response :success
    assert_select "h1", text: "Strings"
    assert_select ".page-banner, header", text: /Instruments we like/
    assert_equal [ "Title open-2", "Title open-1" ], css_select(".result-card .document-title-heading a").map(&:text), "newest added first, as the owner's list"
    assert_select ".result-card img[src='#{THUMBS}open-1.jpg']"
    assert_no_match(/Guest #{owner.id}\b/, response.body)
    assert_no_match(/user[_-]?id|owner/i, css_select("main").to_s)
    assert_not_includes response.body, "/lists/#{list.id}"
    assert_select "main .gallery-note", text: /not listed on this site or in search engines/
  end

  test "it is link-only: noindex and nofollow in the header and the head, no canonical, and the token stays out of Referer headers" do
    list = shared_list
    as_new_visitor
    with_env("SEO_INDEXING" => "on") { view_gallery(list) }

    assert_match(/\Anoindex, nofollow/, response.headers["X-Robots-Tag"])
    assert_match(/\Anoindex, nofollow/, css_select("meta[name=robots]").first["content"])
    assert_empty css_select("link[rel=canonical]")
    assert_equal "same-origin", response.headers["Referrer-Policy"]
    assert_select "link[rel=alternate][type='application/json+oembed']"
  end

  test "robots.txt asks crawlers to keep out of galleries and embeds" do
    with_env("SEO_INDEXING" => "on") { get "/robots.txt" }
    assert_includes response.body, "Disallow: /galleries/"
    assert_includes response.body, "Disallow: /embed/"
  end

  test "a withheld record and a sensitive one are shown without their images, with a note, and their asset paths appear nowhere" do
    list = shared_list
    as_new_visitor
    view_gallery(list)

    assert_response :success
    assert_select ".result-card img[src='#{THUMBS}open-1.jpg']"
    assert_select ".result-card img[src='#{THUMBS}open-2.jpg']"
    assert_not_includes response.body, "#{THUMBS}withheld-1.jpg"
    assert_not_includes response.body, "#{THUMBS}sensitive-1.jpg"
    assert_select ".result-card--no-media", count: 2
    assert_select ".saved-lists-note", text: /2 records are shown without an image/
  end

  test "a record that has left the index drops out of the gallery with a note" do
    list = shared_list
    as_new_visitor
    view_gallery(list)

    assert_select ".result-card", count: 4
    assert_select ".saved-lists-note", text: /1 record in this gallery is no longer in the collection/
  end

  test "a viewer's own choice to view a sensitive record does not bring the image into a gallery" do
    list = shared_list
    as_new_visitor
    with_records(stub_document("sensitive-1")) { post "/catalog/sensitive-1/sensitivity", params: { choice: "view" } }
    view_gallery(list)

    assert_not_includes response.body, "#{THUMBS}sensitive-1.jpg"
  end

  test "the cover is the chosen record when its image may be shown, else the first record with an image, and never a withheld one" do
    list = shared_list
    list.update!(cover_document_id: "open-1")
    as_new_visitor
    view_gallery(list)
    assert_select "figure.gallery-cover img[src='#{THUMBS}open-1.jpg']"

    list.update!(cover_document_id: "withheld-1") # the list shows newest first, so open-2 is the first with an image
    view_gallery(list)
    assert_select "figure.gallery-cover img[src='#{THUMBS}open-2.jpg']"
    assert_not_includes response.body, "#{THUMBS}withheld-1.jpg"
  end

  test "an empty gallery says so" do
    list = shared_list([])
    as_new_visitor
    get "/galleries/#{list.share_token}"

    assert_response :success
    assert_select ".saved-empty__text", text: "This gallery has no records."
  end

  test "it offers Copy link, Cite, Share and embed and Add to my list" do
    list = shared_list
    as_new_visitor
    view_gallery(list)

    assert_select ".saved-toolbar button", text: "Copy link"
    assert_select ".saved-toolbar a[href='/galleries/#{list.share_token}/citations']", text: /Cite/
    assert_select ".saved-toolbar .share__button", text: /Share and embed/
    assert_select ".saved-toolbar form[action='/galleries/#{list.share_token}/copy'] button", text: "Add to my list"
    assert_select "dialog.share__dialog textarea", count: 2
  end

  test "the Cite page cites the gallery's records and returns to the gallery" do
    list = shared_list(%w[open-1])
    as_new_visitor
    with_seeded_menu_cache { with_canned_search(canned_response(docs)) { get "/galleries/#{list.share_token}/citations" } }

    assert_response :success
    assert_select "a[href='/galleries/#{list.share_token}']", text: /Back to Strings/
    assert_match(/Title open-1/, response.body)
  end

  test "with saved records off, galleries are a 404 like the lists they come from" do
    list = shared_list
    was = Rails.configuration.x.saved_records
    Rails.configuration.x.saved_records = false
    get "/galleries/#{list.share_token}"
    assert_response :not_found
  ensure
    Rails.configuration.x.saved_records = was
  end

  # --- Add to my list ---

  test "Add to my list copies the gallery into the viewer's lists, in the same order, and opens the copy" do
    list = shared_list(%w[open-1 open-2 gone-1])
    as_new_visitor

    assert_difference [ "List.count", "User.count" ], 1 do
      post "/galleries/#{list.share_token}/copy"
    end
    copy = List.order(:id).last
    assert_redirected_to "/lists/#{copy.id}"
    assert_equal "Strings", copy.name
    assert_equal "Instruments we like", copy.description
    assert_equal list.list_items.recent.pluck(:document_id), copy.list_items.recent.pluck(:document_id)
    assert_not copy.shared?
    assert_not_equal list.user_id, copy.user_id
  end

  test "a viewer who already has a list of that name gets the copy under the next free name" do
    list = shared_list
    as_new_visitor
    post "/lists", params: { list: { name: "Strings" } }
    post "/galleries/#{list.share_token}/copy"

    assert_equal "Strings (2)", List.order(:id).last.name
  end

  test "a viewer with the most lists allowed is told, nothing is copied, and they stay on the gallery" do
    list = shared_list
    as_new_visitor
    List::MAX_PER_USER.times { |n| post "/lists", params: { list: { name: "Mine #{n}" } } }

    assert_no_difference "List.count" do
      post "/galleries/#{list.share_token}/copy"
    end
    assert_redirected_to "/galleries/#{list.share_token}"
    follow_redirect!
    assert_match(/at most #{List::MAX_PER_USER} lists/, response.body)
  end

  test "copying with a revoked link is a 404 and copies nothing" do
    list = shared_list
    token = list.share_token
    list.unshare!
    as_new_visitor

    assert_no_difference "List.count" do
      post "/galleries/#{token}/copy"
    end
    assert_response :not_found
  end

  # --- Edit: description and cover ---

  test "the owner sets a description and a cover on the edit page, and a cover that is not in the list is refused" do
    list = shared_list(%w[open-1 open-2])
    with_canned_search(canned_response(docs)) { get "/lists/#{list.id}/edit" }
    assert_select "textarea#list_description", text: "Instruments we like"
    assert_select "select#list_cover_document_id option", text: "Title open-2"

    patch "/lists/#{list.id}", params: { list: { name: "Strings", description: "New words", cover_document_id: "open-2" } }
    assert_equal [ "New words", "open-2" ], list.reload.then { |l| [ l.description, l.cover_document_id ] }

    with_canned_search(canned_response(docs)) { patch "/lists/#{list.id}", params: { list: { name: "Strings", cover_document_id: "elsewhere" } } }
    assert_response :unprocessable_content
    assert_equal "open-2", list.reload.cover_document_id
  end

  test "the edit page still renames a list when the index cannot be reached" do
    list = shared_list(%w[open-1])
    with_env("SOLR_URL" => "http://127.0.0.1:1/solr/blacklight-core") do
      Blacklight::Solr::Repository.class_eval { alias_method :__search, :search }
      Blacklight::Solr::Repository.send(:define_method, :search) { |**| raise Blacklight::Exceptions::ECONNREFUSED }
      begin
        get "/lists/#{list.id}/edit"
      ensure
        Blacklight::Solr::Repository.send(:define_method, :search, Blacklight::Solr::Repository.instance_method(:__search))
        Blacklight::Solr::Repository.send(:remove_method, :__search)
      end
    end

    assert_response :success
    assert_select "input#list_name"
    assert_select "select#list_cover_document_id", count: 0
  end
end
