# frozen_string_literal: true

require "test_helper"
require_relative "../support/canned_search"

# GET /catalog/suggest, what the search box's <auto-complete> element shows: options that say what they are and open their search.
# The element (GitHub's, Blacklight's choice) follows a link option on Enter or click and keeps the typed text otherwise.
class CategorisedSuggestTest < ActionDispatch::IntegrationTest
  include CannedSearch

  def facets(fields)
    response = canned_response([])
    response["facet_counts"]["facet_fields"] = fields
    response
  end

  test "each suggestion is an option in the list, a link to its search, with its kind in its name" do
    with_canned_search(facets("creator_ssim" => [ "Grainger, Percy Aldridge", 12 ], "collection_ssim" => [ "Grainger Museum Collection", 9 ],
                              "object_type_ssim" => [], "title_si" => [ "Letter to Grainger", 1 ])) do
      get "/catalog/suggest", params: { q: "grain" }
    end

    assert_response :success
    assert_select "li[role=presentation] > a[role=option].search-suggestion", count: 3
    assert_select "a[role=option][href*='creator_ssim']", text: /Grainger, Percy Aldridge\s*,\s*Creator/
    assert_select "a[role=option][href*='collection_ssim']", text: /Grainger Museum Collection\s*,\s*Collection/
    assert_select "a[role=option][href*='search_field=title']", text: /Letter to Grainger\s*,\s*Title/
    assert_select "a[role=option] .search-suggestion__kind", text: "Creator"
  end

  # Blacklight's suggester stood in for, for the words below only (the "rails" CI job has no Solr)
  FakeService = Struct.new(:suggestions)
  module FakeSuggester
    def suggestions_service
      case params[:q]
      when "grainger m" then FakeService.new([ { "term" => "grainger museum" } ])
      when "broken" then raise Faraday::ConnectionFailed, "down"
      else super
      end
    end
  end
  CatalogController.prepend(FakeSuggester)

  test "with nothing categorised, Blacklight's own suggestions are still offered as plain options that fill the box" do
    with_canned_search(facets({})) { get "/catalog/suggest", params: { q: "grainger m" } }

    assert_response :success
    assert_select "li[role=option]", text: "grainger museum"
    assert_select "a[role=option]", count: 0
  end

  test "a failing suggester gives an empty list, not an error" do
    with_canned_search(->(_params) { raise Faraday::ConnectionFailed, "down" }) { get "/catalog/suggest", params: { q: "broken" } }

    assert_response :success
    assert_select "[role=option]", count: 0
  end
end
