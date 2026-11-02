require "test_helper"
require_relative "../support/canned_search"

# CCS-43: "Why am I seeing these results?" under a search that found nothing or few records. Solr is stood in for, so the CI
# job without a core runs these; the answer is chosen by the filters of each request.
class SearchDiagnosticsTest < ActionDispatch::IntegrationTest
  include CannedSearch

  DOC = { "id" => "emu-1", "title_tsim" => [ "Bird" ], "creator_ssim" => [ "Unknown" ], "object_type_ssim" => [ "drawing" ] }.freeze
  FILTERED = { q: "skull", search_field: "all_fields", f: { has_digital_asset: [ "with" ], collection_ssim: [ "Grainger Museum" ] } }.freeze

  # Zero with both filters; 7 without the collection one; 12 without the default one; 30 with neither
  def answers(counts)
    lambda do |params|
      fq = Array(params["fq"] || params[:fq]).join(" ")
      key = [ fq.include?("has_digital_asset_bsi"), fq.include?("Grainger") ]
      total = counts.fetch(key)
      canned_response(Array.new([ total, 5 ].min) { |n| DOC.merge("id" => "emu-#{n}") }, total: total)
    end
  end

  def visit(params, counts, requests: nil)
    with_seeded_menu_cache do
      with_canned_search(answers(counts)) do |seen|
        get "/catalog", params: params
        requests&.concat(seen)
      end
    end
  end

  COUNTS = { [ true, true ] => 0, [ true, false ] => 7, [ false, true ] => 12, [ false, false ] => 30 }.freeze

  test "an empty search with filters has the panel, closed, with how it was read" do
    visit(FILTERED, COUNTS)

    assert_select "details.why-results:not([open])" do
      assert_select "summary", text: "Why am I seeing these results?"
      assert_select "q", text: "skull"
      assert_select "li", text: /A record must contain your word\./
      assert_select "li", text: /Filter on: With a digital asset\. This filter is on until you take it off\./
      assert_select "li", text: /Filter on: Collection Title: Grainger Museum\./
    end
  end

  test "it counts what each filter hides and links to the search without it" do
    visit(FILTERED, COUNTS)

    assert_select ".why-results a", text: "Take off “With a digital asset”" do |links|
      assert_equal "12 more results", links.first.parent.at_css(".why-results__count").text.delete("()")
      query = Rack::Utils.parse_nested_query(URI(links.first["href"]).query)
      assert_equal "skull", query["q"]
      assert_equal "1", query["any_assets"]
      assert_equal({ "collection_ssim" => [ "Grainger Museum" ] }, query["f"])
    end
    assert_select ".why-results a", text: "Take off “Collection Title: Grainger Museum”" do |links|
      assert_equal "7 more results", links.first.parent.at_css(".why-results__count").text.delete("()")
    end
  end

  test "it says the default digital asset filter may be hiding records, and points to the search tips" do
    visit(FILTERED, COUNTS)

    assert_select ".why-results li", text: /Records without a digital asset are hidden/
    assert_select ".why-results li", text: /Each filter narrows the results/
    assert_select ".why-results a[href$='#advanced-search-tips-title']", text: "Read the search tips"
  end

  test "it makes one request for each filter, and only because the search found nothing or few" do
    seen = []
    visit(FILTERED, COUNTS, requests: seen)
    assert_operator seen.size, :<=, 5, "main search, spelling retry is not needed, unfiltered total, and one for each of two filters"

    seen = []
    visit(FILTERED, { [ true, true ] => 40, [ true, false ] => 50, [ false, true ] => 60, [ false, false ] => 70 }, requests: seen)
    assert_equal 1, seen.size, "a page of results asks nothing more"
    assert_select ".why-results", count: 0
  end

  test "a single filter that hides everything reuses the count the page already made" do
    seen = []
    visit({ q: "skull", f: { has_digital_asset: [ "with" ] } }, { [ true, false ] => 0, [ false, false ] => 44 }, requests: seen)

    assert_select ".why-results a", text: "Take off “With a digital asset”"
    assert_select ".why-results__count", text: "(44 more results)"
    assert_equal 2, seen.size, "the search, and the same search without its filter"
  end

  test "a search that finds nothing even without its filters has no filter to blame" do
    visit(FILTERED, { [ true, true ] => 0, [ true, false ] => 0, [ false, true ] => 0, [ false, false ] => 0 })

    assert_select ".why-results a", text: /Take off/, count: 0
    assert_select ".why-results li", text: "Taking off any one filter does not add results."
  end

  test "a few results get the panel too" do
    visit({ q: "skull", any_assets: "1", f: { collection_ssim: [ "Grainger Museum" ] } }, { [ false, true ] => 3, [ false, false ] => 20 })

    assert_select ".result-card", count: 3
    assert_select ".why-results a", text: "Take off “Collection Title: Grainger Museum”"
    assert_select ".why-results__count", text: "(17 more results)"
  end

  test "quoted phrases, operators and long searches are explained in plain words" do
    visit({ q: 'the "human skull" in a very long search of eight words', any_assets: "1" }, { [ false, false ] => 0 })
    assert_select ".why-results li", text: /Exact phrase, found only with the words together/
    assert_select ".why-results li", text: /up to 2 may be missing/
    assert_select ".why-results li", text: /long search needs most of its words/

    visit({ q: "skull AND bone", any_assets: "1" }, { [ false, false ] => 0 })
    assert_select ".why-results li", text: /AND, OR, NOT, \+ or -, or a field name/
  end

  test "an Advanced search is read row by row" do
    clauses = { "0" => { field: "title", op: "must", query: "skull" }, "1" => { field: "creator", op: "must_not", query: "bone" } }
    visit({ clause: clauses, any_assets: "1" }, { [ false, false ] => 0 })

    assert_select ".why-results li", text: "Title must contain skull."
    assert_select ".why-results li", text: "Creator must not contain bone."
    assert_select ".why-results li", text: /Every row of an Advanced search/
  end

  test "nothing a visitor should not see: no field names, no Solr words" do
    visit(FILTERED, COUNTS)

    text = css_select(".why-results").text
    assert_no_match(/_ssim|_tsim|_bsi|Solr|edismax|\bfq\b|\bqf\b/i, text)
  end

  test "the page is not given the panel when there is no search at all" do
    visit({ sort: "title" }, { [ false, false ] => 3 })
    assert_select ".why-results", count: 0
  end
end
