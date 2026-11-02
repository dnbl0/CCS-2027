require "test_helper"
require_relative "../support/canned_search"

# CCS-39: each result card says why it matched. Solr is stood in for (CannedSearch), so these run in the CI job that has no core;
# the system test and SearchHighlightingTest check the real thing.
class SearchRationaleTest < ActionDispatch::IntegrationTest
  include CannedSearch

  DOCS = [
    { "id" => "emu-1", "title_tsim" => [ "Modified ancestor skull" ], "creator_ssim" => [ "Melanesian - Papua New Guinea" ],
      "creator_tsim" => [ "Melanesian - Papua New Guinea" ], "object_type_ssim" => [ "modified ancestor" ], "collection_ssim" => [ "University Art Collection" ] },
    { "id" => "emu-2", "title_tsim" => [ "Bird" ], "creator_ssim" => [ "Unknown" ], "object_type_ssim" => [ "drawing" ] },
    { "id" => "emu-3", "title_tsim" => [ "Sensitive thing" ], "restrictions_tsi" => [ "Culturally sensitive images" ], "object_type_ssim" => [ "drawing" ] }
  ].freeze

  HIGHLIGHTS = {
    "emu-1" => { "title_tsim" => [ "Modified ancestor <mark>skull</mark>" ], "creator_tsim" => [ "<mark>Melanesian</mark> - Papua New Guinea" ],
                 "description_tsim" => [ "A <mark>skull</mark> &lt;script&gt;alert(1)&lt;/script&gt; from the Sepik" ] },
    "emu-2" => { "description_tsim" => [ "Looks like a <mark>skull</mark>" ] },
    "emu-3" => { "description_tsim" => [ "A <mark>skull</mark> that is withheld" ], "title_tsim" => [ "Sensitive <mark>skull</mark>" ] }
  }.freeze

  def search(highlighting, params: { q: "skull", any_assets: "1", view: "list" })
    with_seeded_menu_cache do
      with_canned_search(canned_response(DOCS, highlighting: highlighting)) { get "/catalog", params: params }
    end
  end

  test "the title and the creator show the matched words in <mark>, and the line names the fields" do
    search(HIGHLIGHTS)

    assert_response :success
    assert_select "article[data-document-id='emu-1'] .document-title-heading a mark", text: "skull"
    assert_select "article[data-document-id='emu-1'] .result-card__lines li mark", text: "Melanesian"
    assert_select "article[data-document-id='emu-1'] .result-card__matched", text: "Matched in: Title, Creator, Description"
  end

  test "the words in a field the card does not show come as a short snippet, escaped" do
    search(HIGHLIGHTS)

    assert_select "article[data-document-id='emu-1'] .result-card__snippet mark", text: "skull"
    assert_select "article[data-document-id='emu-1'] .result-card__snippet script", count: 0
    assert_includes css_select("article[data-document-id='emu-1'] .result-card__snippet").first.inner_html, "&lt;script&gt;"
  end

  test "a record whose words are only in a hidden field has the line and a snippet, but its title is not marked" do
    search(HIGHLIGHTS)

    assert_select "article[data-document-id='emu-2'] .result-card__matched", text: "Matched in: Description"
    assert_select "article[data-document-id='emu-2'] .document-title-heading a mark", count: 0
    assert_select "article[data-document-id='emu-2'] .result-card__snippet", text: "Looks like a skull"
  end

  test "a sensitive record is marked and named, but no snippet of its description is shown" do
    search(HIGHLIGHTS)

    assert_select "article[data-document-id='emu-3'] .result-card__matched", text: "Matched in: Title, Description"
    assert_select "article[data-document-id='emu-3'] .result-card__snippet", count: 0
  end

  test "results without Solr highlights have no rationale, no marks, and the same cards" do
    search(nil)

    assert_response :success
    assert_select ".result-card", count: 3
    assert_select ".result-card__why", count: 0
    assert_select ".result-card mark", count: 0
    assert_select "article[data-document-id='emu-1'] .document-title-heading a", text: "Modified ancestor skull"
  end

  test "a record Solr matched in no field the site names says it matched on a related word" do
    search({ "emu-1" => {}, "emu-2" => {}, "emu-3" => {} })

    assert_select ".result-card__matched", count: 3, text: I18n.t("nexus_ccs.rationale.other")
    assert_select ".result-card mark", count: 0
  end

  test "marking never changes the text of the title or lines, whatever the record contains" do
    docs = [ { "id" => "x-1", "title_tsim" => [ "<img src=x onerror=alert(1)> skull & bones" ], "creator_ssim" => [ "<b>skull</b>" ], "creator_tsim" => [ "skull" ] } ]
    highlights = { "x-1" => { "title_tsim" => [ "&lt;img src=x onerror=alert(1)&gt; <mark>skull</mark> &amp; bones" ], "creator_tsim" => [ "<mark>skull</mark>" ] } }
    with_seeded_menu_cache { with_canned_search(canned_response(docs, highlighting: highlights)) { get "/catalog", params: { q: "skull", any_assets: "1" } } }

    assert_select "article img[onerror]", count: 0
    assert_select "article b", count: 0
    assert_select ".document-title-heading a mark", text: "skull"
    assert_includes css_select(".document-title-heading a").first.inner_html, "&lt;img src=x onerror=alert(1)&gt; <mark>skull</mark> &amp; bones"
    assert_includes css_select(".result-card__lines li").first.inner_html, "&lt;b&gt;<mark>skull</mark>&lt;/b&gt;"
  end

  test "highlighting is asked of Solr for a search with words, and not for a browse" do
    seen = nil
    with_seeded_menu_cache { with_canned_search(canned_response(DOCS)) { |requests| get "/catalog", params: { q: "skull", any_assets: "1" }; seen = requests.dup } }
    assert(seen.any? { |params| params["hl"] }, "the search asks for highlights")

    with_seeded_menu_cache { with_canned_search(canned_response(DOCS)) { |requests| get "/catalog", params: { any_assets: "1", f: { collection_ssim: [ "Grainger Museum" ] } }; seen = requests.dup } }
    assert(seen.none? { |params| params["hl"] }, "a browse has no words to find")
  end
end
