# frozen_string_literal: true

require "test_helper"
require_relative "../support/canned_search"

class CardDescriptionTest < ActiveSupport::TestCase
  include CannedSearch

  def answer(classification: [ "prints", 3, "drawings", 2, "paintings", 1 ], collections: [ "University Art Collection", 4, "Grainger Museum Collection", 2, "[other]", 1 ])
    canned_response([]).tap { |body| body["facet_counts"]["facet_fields"] = { "classification_ssim" => classification, "collection_ssim" => collections } }
  end

  def describe(**options) = with_canned_search(answer(**options.slice(:classification, :collections))) { |_seen| CardDescription.for(filter: "production_place_ssim:\"Australia\"", **options.except(:classification, :collections)) }

  test "the two commonest kinds of record and collections" do
    assert_equal "Includes prints, drawings. Held in University Art Collection and Grainger Museum Collection.", describe
  end

  test "a card that is a kind itself lists no kinds" do
    assert_equal "Held in University Art Collection and Grainger Museum Collection.", describe(kinds: false)
  end

  test "the earliest period says so" do
    assert_match(/\AThe earliest objects\. Includes prints/, describe(earliest: true))
  end

  test "noise values and the other bucket are left out, and nothing found is an empty description" do
    assert_equal "Includes prints. Held in University Art Collection.", describe(classification: [ "Unknown", 9, "prints", 3 ], collections: [ "[other]", 5, "University Art Collection", 2 ])
    assert_equal "", describe(classification: [], collections: [])
  end

  test "when the index cannot answer the description is empty" do
    assert_equal "", CardDescription.for(filter: "x:y")
  end
end
