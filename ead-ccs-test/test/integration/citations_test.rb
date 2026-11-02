require "test_helper"

# CCS-137: citations for the records of a list and of the saved records. Reads records from the Solr core at SOLR_URL.
class CitationsTest < ActionDispatch::IntegrationTest
  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL"
  end

  def record_ids
    @record_ids ||= begin
      get "/catalog", params: { q: "skull", any_assets: "1", format: :json }
      JSON.parse(response.body)["data"].first(2).map { |doc| doc["id"] }
    end
  end

  def list_with_records
    post "/lists", params: { list: { name: "Skulls" } }
    list = List.order(:id).last
    record_ids.each { |id| list.list_items.create!(document_id: id) }
    list
  end

  setup { needs_solr }

  test "a list's records are all selected to begin with, in APA, with their citations and persistent links" do
    list = list_with_records
    get "/lists/#{list.id}/citations"

    assert_response :success
    assert_select "h1", text: "Cite records"
    assert_select "input[type=radio][name=style]", count: 4
    assert_select "input[type=radio][value=apa][checked]"
    assert_select "input[type=checkbox][name='ids[]'][checked]", count: 2
    assert_select "#cite-results-heading", text: "2 citations in APA 7th"
    assert_select ".cite-page__reference", count: 2
    record_ids.each { |id| assert_select ".cite-page__reference", text: %r{/catalog/#{Regexp.escape(id)}} }
    assert_select "button[data-action='clipboard#copy']", text: "Copy citations"
    assert_select "a[download][href*='citations.txt'], a[download][href$='.txt'], a[download][href*='.txt?']", text: /Download citations/
  end

  test "choosing a style and one record shows that citation only, and a style it does not know is APA" do
    list = list_with_records
    get "/lists/#{list.id}/citations", params: { style: "harvard", ids: [ record_ids.first ], submitted: 1 }

    assert_select "input[type=radio][value=harvard][checked]"
    assert_select "input[type=checkbox][name='ids[]'][checked]", count: 1
    assert_select "#cite-results-heading", text: "1 citation in Harvard"
    assert_select ".cite-page__reference", text: /viewed \d+ \w+ \d{4}, </
    assert_select "[data-controller=focus-on-load]#cite-results-heading"

    get "/lists/#{list.id}/citations", params: { style: "turabian" }
    assert_select "input[type=radio][value=apa][checked]"
  end

  test "submitting with no record selected says so" do
    list = list_with_records
    get "/lists/#{list.id}/citations", params: { style: "mla", submitted: 1 }

    assert_select ".cite-page__reference", count: 0
    assert_select "[role=alert]", text: /Select at least one record/
  end

  test "the download is a text file of the selected citations, blank-line separated, in the chosen style" do
    list = list_with_records
    get "/lists/#{list.id}/citations.txt", params: { style: "chicago", ids: record_ids }

    assert_response :success
    assert_match %r{\Atext/plain; charset=utf-8}, response.content_type
    assert_match(/attachment; filename="citations-chicago.txt"/, response.headers["Content-Disposition"])
    assert_equal 2, response.body.strip.split("\n\n").size
    assert_match(/\(accessed \d+ \w+ \d{4}\)/, response.body)
  end

  test "an empty list has nothing to cite, and another visitor's list is not found" do
    post "/lists", params: { list: { name: "Empty" } }
    get "/lists/#{List.order(:id).last.id}/citations"
    assert_select ".saved-empty__text", text: /no records to cite/

    get "/lists/999999/citations"
    assert_redirected_to "/lists"
  end

  test "the list page links to its citations once it has records" do
    list = list_with_records
    get "/lists/#{list.id}"
    assert_select "a[href='/lists/#{list.id}/citations']", text: "Cite records"
  end

  test "the saved records have citations too, and the saved page links to them" do
    record_ids.each { |id| put "/bookmarks/#{id}" }
    get "/bookmarks"
    assert_select "a[href='/bookmarks/citations']", text: "Cite records"

    get "/bookmarks/citations", params: { style: "mla" }
    assert_response :success
    assert_select "#cite-results-heading", text: "2 citations in MLA 9th"
    assert_select ".cite-page__reference", text: /Accessed \d+ \w+\.? \d{4}\./, count: 2
  end
end
