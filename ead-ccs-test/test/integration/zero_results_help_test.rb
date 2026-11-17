# frozen_string_literal: true

require "test_helper"
require_relative "../support/canned_search"

# The empty results page's extra help (ZeroResults, SearchService): each filter taken off on its own with what it would find, and three
# related categories. Solr is stood in for, answering each kind of request the page makes.
class ZeroResultsHelpTest < ActionDispatch::IntegrationTest
  include CannedSearch

  RELATED = { "collection_ssim" => [ "Grainger Museum Collection", 40 ], "object_type_ssim" => [ "photograph", 25 ], "creator_ssim" => [ "Grainger, Percy", 9 ] }.freeze

  # The page's own search finds nothing; the count without filters finds 120 (with the related facets); taking off the collection finds 7
  def solr(unfiltered: 120, related: RELATED, words: [])
    lambda do |params|
      params = params.to_h.with_indifferent_access
      if params[:rows].to_i.positive? then canned_response([])
      elsif params[:"facet.contains"]
        response = canned_response([])
        response["facet_counts"]["facet_fields"] = { "creator_ssim" => [], "collection_ssim" => [], "object_type_ssim" => words, "title_si" => [] }
        response
      elsif Array(params[:"facet.field"]) == ZeroResults::RELATED_FIELDS.keys
        response = canned_response([], total: unfiltered)
        response["facet_counts"]["facet_fields"] = related
        response
      else
        canned_response([], total: Array(params[:fq]).join.include?("collection_ssim") ? 0 : 7)
      end
    end
  end

  def search(params, answer = solr)
    with_seeded_menu_cache { with_canned_search(answer) { get "/catalog", params: params } }
    assert_response :success
  end

  test "an empty page with several filters lists each one that would find something, with its count, and three related categories" do
    search(q: "skull", search_field: "all_fields", f: { has_digital_asset: [ "with" ], collection_ssim: [ "Archives" ] })

    assert_select ".results-empty__removals li", count: 1
    assert_select ".results-empty__removals a", text: "Without Collection Title: Archives: 7 results"
    assert_select ".results-empty__related li", count: 3
    link = css_select(".results-empty__related a").first
    assert_match(/Grainger Museum Collection/, link.text)
    query = Rack::Utils.parse_nested_query(URI(link["href"]).query)
    assert_equal "skull", query["q"]
    assert_equal [ "Grainger Museum Collection" ], query.dig("f", "collection_ssim")
  end

  test "words that find nothing at all are matched against category names instead" do
    search({ q: "photogr", search_field: "all_fields", any_assets: "1" }, solr(unfiltered: 0, words: [ "photograph", 25 ]))

    assert_select ".results-empty__related a", text: /photograph\s*\(Object type\)/
    assert_select ".results-empty__removals", count: 0
  end

  test "nothing to suggest leaves the page as it was" do
    search({ q: "zzqx", search_field: "all_fields", any_assets: "1" }, solr(unfiltered: 0))

    assert_select ".results-empty__help", count: 0
    assert_select ".results-empty__new-search"
  end
end
