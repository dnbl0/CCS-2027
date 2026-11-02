require "test_helper"
require_relative "../support/canned_search"
require_relative "../support/env_override"

# CCS-40: ticking results, kept in the visitor's session, and the page that lists only those, in the order chosen.
class ResultsSelectionTest < ActionDispatch::IntegrationTest
  include CannedSearch
  include EnvOverride

  DOCS = (1..3).map do |n|
    { "id" => "emu-#{n}", "title_tsim" => [ "Record #{n}" ], "creator_ssim" => [ "Maker #{n}" ], "object_type_ssim" => [ "drawing" ] }
  end.freeze

  def tick(*ids, scope: ids, intent: "update", **extra)
    post "/selection", params: { intent: intent, page_ids: scope, ids: ids, return_to: "/catalog?q=skull" }.merge(extra)
  end

  def selected_ids
    Selection.new(session).ids
  end

  def results_page
    with_seeded_menu_cache { with_canned_search(canned_response(DOCS)) { get "/catalog", params: { q: "skull", any_assets: "1", view: "list" } } }
  end

  test "ticking records keeps them in the order chosen, once each, and goes back to the results with a notice" do
    tick("emu-2")
    tick("emu-3", "emu-1", "emu-2", scope: %w[emu-1 emu-2 emu-3])

    assert_redirected_to "/catalog?q=skull"
    assert_equal 303, response.status
    assert_equal %w[emu-2 emu-3 emu-1], selected_ids
    assert_equal "3 records selected", flash[:notice]
  end

  test "unticking takes a record out and leaves the other pages' records alone" do
    tick("emu-9")
    tick("emu-1", "emu-2", scope: %w[emu-1 emu-2 emu-3])
    tick("emu-2", scope: %w[emu-1 emu-2 emu-3])

    assert_equal %w[emu-9 emu-2], selected_ids
  end

  test "Select all on this page adds the page's records, and Clear selection empties it" do
    tick(intent: "all", scope: %w[emu-1 emu-2 emu-3])
    assert_equal %w[emu-1 emu-2 emu-3], selected_ids

    tick(intent: "clear", scope: [])
    assert_empty selected_ids
    assert_equal "No records selected", flash[:notice]
  end

  test "at most 50 can be selected: the rest are refused with a message, and the 50 stay" do
    ids = (1..55).map { |n| "rec-#{n}" }
    tick(*ids, scope: ids)

    assert_equal 50, selected_ids.size
    assert_equal ids.first(50), selected_ids
    assert_match(/up to 50 records/, flash[:alert])
    assert_nil flash[:notice]
  end

  test "JavaScript asks for JSON and is told what is selected, and what did not fit" do
    ids = (1..52).map { |n| "rec-#{n}" }
    post "/selection", params: { intent: "update", page_ids: ids, ids: ids }, headers: { "Accept" => "application/json" }
    body = JSON.parse(response.body)

    assert_response :success
    assert_equal 50, body["count"]
    assert_equal 50, body["max"]
    assert_equal true, body["full"]
    assert_equal %w[rec-51 rec-52], body["refused"]
    assert_equal ids.first(50), body["ids"]
  end

  test "the form comes back only to a page of this site" do
    post "/selection", params: { intent: "update", page_ids: [ "a" ], ids: [ "a" ], return_to: "https://evil.example/phish" }
    assert_redirected_to "/selection"

    post "/selection", params: { intent: "update", page_ids: [ "a" ], ids: [ "a" ], return_to: "//evil.example" }
    assert_redirected_to "/selection"
  end

  test "hostile parameters do not break it" do
    post "/selection", params: { intent: "update", page_ids: { a: "b" }, ids: "c" }
    assert_response :redirect
    post "/selection", params: { intent: "nonsense", page_ids: [ "a" ], ids: [ "a" ] }
    assert_equal %w[a], selected_ids
  end

  test "another visitor's selection is not visible" do
    tick("emu-1", "emu-2")
    mine = cookies.to_hash.slice("_ccs_session")

    reset!
    with_seeded_menu_cache { with_canned_search(canned_response(DOCS)) { get "/selection" } }
    assert_response :success
    assert_select ".saved-empty", text: /not selected any records/
    assert_select ".result-card", count: 0
    assert_not_equal mine, cookies.to_hash.slice("_ccs_session")
  end

  test "the results page shows a checkbox on every card, named by the record's title, ticked for the chosen ones" do
    tick("emu-2")
    results_page

    assert_select "form#selection-form[action='/selection'][method=post]" do
      assert_select "p[role=status][aria-live=polite]", text: "1 record selected"
      assert_select "button", text: "Select all on this page"
      assert_select "button", text: "Clear selection"
      assert_select "a[href='/selection']", text: "View selected (1)"
    end
    assert_select "article.result-card", count: 3
    assert_select "input[type=checkbox][form=selection-form][name='ids[]']", count: 3
    assert_select "input#select-emu-2[checked]", count: 1
    assert_select "input#select-emu-1[checked]", count: 0
    assert_select "label[for=select-emu-2]", text: /\ASelect: Record 2\z/
    assert_select "label[for=select-emu-2] .visually-hidden", text: ": Record 2"
    assert_equal %w[emu-1 emu-2 emu-3], css_select("form#selection-form input[name='page_ids[]']").map { |input| input["value"] }
  end

  test "with no records on the page there is no selection form" do
    with_seeded_menu_cache { with_canned_search(canned_response([])) { get "/catalog", params: { q: "zzz", any_assets: "1" } } }

    assert_select "form#selection-form", count: 0
  end

  test "the selection page lists only the selected records, as cards, in the order chosen" do
    tick("emu-3", "emu-1")
    with_seeded_menu_cache do
      with_canned_search(->(_params) { canned_response([ DOCS[2], DOCS[0] ]) }) { get "/selection" }
    end

    assert_response :success
    assert_select "h2", text: "2 selected records"
    assert_equal %w[emu-3 emu-1], css_select("article.result-card").map { |card| card["data-document-id"] }
    assert_select "article.result-card input[type=checkbox][checked]", count: 2
    assert_select "a[href='/selection/citations']", text: "Cite selected records"
  end

  test "the selection page is personal: not indexed, and not in robots.txt's allowed paths" do
    get "/selection"

    assert_match(/noindex, nofollow/, response.headers["X-Robots-Tag"])
    with_env("SEO_INDEXING" => "on") { get "/robots.txt" }
    assert_includes response.body, "Disallow: /selection"
  end

  test "Add selected to a list reaches the list's items with every selected id, each once" do
    post "/lists", params: { list: { name: "Skulls" } }
    list = List.order(:id).last
    post "/lists/#{list.id}/items", params: { document_ids: %w[emu-1 emu-2 emu-1] }

    assert_equal %w[emu-1 emu-2], list.list_items.order(:id).pluck(:document_id)
    assert_equal "2 records added to Skulls.", flash[:notice]

    post "/lists/#{list.id}/items", params: { document_ids: %w[emu-1 emu-3] }
    assert_equal "1 record added to Skulls.", flash[:notice]
  end

  test "Cite selected cites the selected records, in the order chosen, and nothing else" do
    needs_solr
    get "/catalog", params: { q: "skull", any_assets: "1", format: :json }
    ids = JSON.parse(response.body)["data"].first(2).map { |doc| doc["id"] }.reverse
    tick(*ids)

    get "/selection/citations"
    assert_response :success
    assert_select ".cite-page__reference", count: 2
    assert_select "input[name='ids[]']", count: 2
    assert_match(/noindex, nofollow/, response.headers["X-Robots-Tag"])
  end

  test "a record in the selection shows where it is, and previous and next selected links (against the core)" do
    needs_solr
    get "/catalog", params: { q: "skull", any_assets: "1", format: :json }
    ids = JSON.parse(response.body)["data"].first(3).map { |doc| doc["id"] }
    tick(*ids)

    get "/catalog/#{ids[1]}"
    assert_select "nav.selection-stepper[aria-label='Selected records']" do
      assert_select ".selection-stepper__position", text: "Selected record 2 of 3"
      assert_select "a[rel=prev][href='/catalog/#{ids[0]}']", text: "Previous selected record"
      assert_select "a[rel=next][href='/catalog/#{ids[2]}']", text: "Next selected record"
      assert_select "a[href='/selection']"
    end

    get "/catalog/#{ids[0]}"
    assert_select "a[rel=prev]", count: 0
    reset!
    get "/catalog/#{ids[1]}"
    assert_select "nav.selection-stepper", count: 0
  end

  test "the selection works with saved records off" do
    was = Rails.configuration.x.saved_records
    Rails.configuration.x.saved_records = false
    tick("emu-1")
    assert_equal %w[emu-1], selected_ids
    with_seeded_menu_cache { with_canned_search(canned_response([ DOCS[0] ])) { get "/selection" } }
    assert_response :success
    assert_select ".selection-lists", count: 0
    assert_select ".bulk-select", count: 0
  ensure
    Rails.configuration.x.saved_records = was
  end
end
