require "test_helper"
require_relative "../support/stub_records"

# CCS-58: the comparison page, per access tier. The records are stubbed (no Solr needed). A record whose images the visitor may not
# be shown cannot be added and is never drawn, and none of its image addresses reach the page.
class CompareTest < ActionDispatch::IntegrationTest
  include StubRecords

  def add(id) = post("/compare/items", params: { id: id })

  def panes = css_select(".compare-pane")

  test "records added from their pages are panes with title, accession number and licence, in the order added" do
    a = stub_document("open-1")
    b = stub_document("view-1", licence: "Copyright - Current")
    with_records(a, b) do
      add("open-1")
      assert_redirected_to "/catalog/open-1#digital-assets"
      add("view-1")
      get "/compare"
    end

    assert_response :success
    assert_equal 2, panes.size
    assert_select ".compare-pane__title", text: "Title of open-1"
    assert_select ".compare-pane__title", text: "Title of view-1"
    assert_select ".compare-pane__details", text: /ACC-open-1/
    assert_select ".compare-pane__details", text: /Copyright - Current/
    assert_select ".compare-pane[data-sources]"
    assert_select "input[type=checkbox][data-compare-target=link]"
    assert_select "label", text: "Link zoom and pan"
  end

  test "a withheld record cannot be added, and its images are not on any page" do
    withheld = stub_document("request-1", licence: "ICIP Rights")
    with_records(withheld) do
      add("request-1")
      assert_redirected_to "/catalog/request-1#digital-assets"
      get "/compare"
    end

    assert_equal 0, panes.size
    assert_not_includes response.body, "/digital-assets/"
    assert_not_includes response.body, "Title of request-1"
  end

  test "a sensitive record cannot be added until the visitor chooses to view it" do
    sensitive = stub_document("sensitive-1", restrictions_tsi: [ "Culturally sensitive images" ])
    with_records(sensitive) do
      add("sensitive-1")
      get "/compare"
      assert_equal 0, panes.size
      assert_not_includes response.body, "/digital-assets/"

      post "/catalog/sensitive-1/sensitivity", params: { choice: "hide" }
      add("sensitive-1")
      get "/compare"
      assert_equal 0, panes.size

      post "/catalog/sensitive-1/sensitivity", params: { choice: "view" }
      add("sensitive-1")
      get "/compare"
      assert_equal 1, panes.size
    end
  end

  test "a record added and then hidden or withheld drops out of the comparison, with a note" do
    sensitive = stub_document("sensitive-1", restrictions_tsi: [ "Culturally sensitive images" ])
    open = stub_document("open-1")
    with_records(sensitive, open) do
      post "/catalog/sensitive-1/sensitivity", params: { choice: "view" }
      add("sensitive-1")
      add("open-1")
      post "/catalog/sensitive-1/sensitivity", params: { choice: "hide" }
      get "/compare"
    end

    assert_equal 1, panes.size
    assert_select ".compare__note", text: /1 record you added is no longer available/
    assert_not_includes response.body, "Title of sensitive-1"
  end

  test "at most four records, and a record is in the list once" do
    docs = (1..5).map { |n| stub_document("open-#{n}") }
    with_records(*docs) do
      docs.each { |document| add(document.id) }
      follow_redirect!
      assert_match(/The comparison holds 4 records/, response.body)

      add("open-1")
      get "/compare"
    end

    assert_equal 4, panes.size
    assert_select ".compare-pane__title", text: "Title of open-5", count: 0
    assert_select ".compare__panes--4"
  end

  test "a record is removed from the comparison, and the list can be cleared" do
    with_records(stub_document("open-1"), stub_document("open-2")) do
      add("open-1")
      add("open-2")
      delete "/compare/items/open-1"
      assert_redirected_to "/compare"
      get "/compare"
      assert_equal 1, panes.size

      delete "/compare"
      get "/compare"
    end

    assert_equal 0, panes.size
    assert_select ".saved-empty__text", text: /Nothing to compare yet/
  end

  test "a record that is not in the index cannot be added" do
    with_records { add("nothing") }

    assert_response :not_found
  end

  test "one record's images side by side: two panes, each with a selector over every image; panes can be added up to the image count" do
    with_records(stub_document("open-1", "digital_asset_large_paths_ssim" => StubRecords::OPEN_LARGE + [ "/digital-assets/large/0000_013_1_pf.jpg" ],
                                          "digital_asset_paths_ssim" => StubRecords::OPEN_THUMBS + [ "/digital-assets/thumbs/0000_013_1_pf.jpg" ])) do
      get "/compare", params: { record: "open-1" }
      assert_equal 2, panes.size
      assert_select ".compare-pane select option", count: 6
      assert_select "a", text: "Add a pane"
      assert_select "a", text: "Remove a pane", count: 0

      get "/compare", params: { record: "open-1", panes: 3 }
      assert_equal 3, panes.size
      assert_select "a", text: "Add a pane", count: 0
      assert_select "a", text: "Remove a pane"

      get "/compare", params: { record: "open-1", panes: 9 }
      assert_equal 3, panes.size, "no more panes than images"
    end
  end

  test "one record's images: a withheld or unchosen sensitive record is a 404 with no address in it" do
    with_records(stub_document("request-1", licence: "ICIP Rights"), stub_document("sensitive-1", restrictions_tsi: [ "Culturally sensitive" ])) do
      %w[request-1 sensitive-1].each do |id|
        get "/compare", params: { record: id }
        assert_response :not_found
        assert_not_includes response.body, "/digital-assets/"
      end
    end
  end

  test "the comparison is a personal page: noindex, nofollow, in the browser's tab title" do
    with_records { get "/compare" }

    assert_match(/noindex, nofollow/, response.headers["X-Robots-Tag"].to_s)
    assert_select "title", text: /Compare/
    assert_select "meta[name=robots][content*=noindex]"
  end
end
