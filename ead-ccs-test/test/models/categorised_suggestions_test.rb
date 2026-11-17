# frozen_string_literal: true

require "test_helper"
require_relative "../support/canned_search"

# Suggestions as you type, each saying what it is (CategorisedSuggestions): creators, collections, object types and titles that
# contain the typed words, from one request for facet values (facet.contains), so it works on today's index with no Solr change.
class CategorisedSuggestionsTest < ActiveSupport::TestCase
  include CannedSearch

  def answer(fields)
    response = canned_response([])
    response["facet_counts"]["facet_fields"] = fields
    response
  end

  FIELDS = {
    "creator_ssim" => [ "Grainger, Percy Aldridge", 120, "Grainger, Ella Viola", 40 ],
    "collection_ssim" => [ "Grainger Museum Collection", 900 ],
    "object_type_ssim" => [],
    "title_si" => [ "Letter to Grainger", 2 ]
  }.freeze

  test "one request for the four kinds, matching the typed text anywhere and ignoring case, without records" do
    with_canned_search(answer(FIELDS)) do |seen|
      CategorisedSuggestions.for("grain")
      params = seen.sole.to_h.with_indifferent_access

      assert_equal 0, params[:rows].to_i
      assert_equal %w[creator_ssim collection_ssim object_type_ssim title_si], Array(params["facet.field"])
      assert_equal "grain", params["facet.contains"]
      assert_equal "true", params["facet.contains.ignoreCase"].to_s
    end
  end

  test "each suggestion has its kind and the search it opens: a creator or type filter, the whole collection, or a title search" do
    suggestions = with_canned_search(answer(FIELDS)) { CategorisedSuggestions.for("grain") }

    assert_equal [ [ "Grainger, Percy Aldridge", "Creator" ], [ "Grainger, Ella Viola", "Creator" ], [ "Grainger Museum Collection", "Collection" ],
                   [ "Letter to Grainger", "Title" ] ], suggestions.map { |item| [ item.value, item.kind ] }
    creator = suggestions.first.query
    assert_equal({ "creator_ssim" => [ "Grainger, Percy Aldridge" ] }, creator[:f].transform_keys(&:to_s))
    assert_equal "1", creator[:any_assets]
    assert_equal({ q: "Letter to Grainger", search_field: "title" }, suggestions.last.query)
  end

  test "an object type is a filter on object type" do
    fields = FIELDS.merge("object_type_ssim" => [ "photograph", 300 ])
    type = with_canned_search(answer(fields)) { CategorisedSuggestions.for("photo") }.find { |item| item.kind == "Object type" }

    assert_equal({ "object_type_ssim" => [ "photograph" ] }, type.query[:f].transform_keys(&:to_s))
  end

  test "too short, too long or blank text asks nothing; Solr failing gives nothing" do
    with_canned_search(answer(FIELDS)) do |seen|
      [ "", " g ", "x" * 101 ].each { |text| assert_equal [], CategorisedSuggestions.for(text) }
      assert_empty seen
    end
    with_canned_search(->(_params) { raise Faraday::ConnectionFailed, "down" }) { assert_equal [], CategorisedSuggestions.for("grain") }
  end
end
