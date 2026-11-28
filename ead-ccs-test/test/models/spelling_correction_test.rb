# frozen_string_literal: true

require "test_helper"

class SpellingCorrectionTest < ActiveSupport::TestCase
  def response(documents:, collation: nil, words: [])
    Struct.new(:documents, :spelling)
          .new(documents, Struct.new(:collation, :words).new(collation, words))
  end

  test "corrects a query that found nothing" do
    correction = SpellingCorrection.from("anatommy", response(documents: [], collation: "anatomy"))

    assert_equal "anatommy", correction.original
    assert_equal "anatomy", correction.corrected
  end

  test "carries the other word suggestions, minus the auto-corrected term" do
    correction = SpellingCorrection.from("cavinet",
      response(documents: [], collation: "cabinet", words: %w[Cabinet covenant caviar]))

    assert_equal %w[covenant caviar], correction.suggestions
  end

  test "has no other suggestions when the collation is the only word" do
    correction = SpellingCorrection.from("cavinet",
      response(documents: [], collation: "cabinet", words: %w[cabinet]))

    assert_empty correction.suggestions
  end

  test "leaves a search that found something alone" do
    assert_nil SpellingCorrection.from("anatomy", response(documents: [ :a_hit ], collation: "botany"))
  end

  # Solr echoes the query back when it has nothing better. Retrying just repeats the empty search.
  test "ignores a collation that matches the query" do
    assert_nil SpellingCorrection.from("anatomy", response(documents: [], collation: "Anatomy"))
  end

  test "does nothing without a collation" do
    assert_nil SpellingCorrection.from("anatommy", response(documents: []))
    assert_nil SpellingCorrection.from("", response(documents: [], collation: "anatomy"))
  end

  # CCS-292: "gardin of coty" was corrected to "garden of copy", because "copy" is the commoner word, though no record has
  # the two words near each other. Of Solr's collations, the first whose words sit together in a record wins.
  def solr_response(*collations)
    { "response" => { "docs" => [] }, "spellcheck" => { "collations" => collations.flat_map { |c| [ "collation", c ] } } }
  end

  test "prefers the collation whose words appear together in the most records" do
    near = { "garden of copy" => 2, "garden of city" => 5, "gordon of copy" => 1 }
    collation = SpellingCorrection.best_collation(solr_response("garden of copy", "garden of city", "gordon of copy"), ->(c) { near.fetch(c) })

    assert_equal "garden of city", collation
  end

  test "keeps Solr's order between collations as often together" do
    collation = SpellingCorrection.best_collation(solr_response("melbourne university", "melburne university"), ->(_) { 4 })

    assert_equal "melbourne university", collation
  end

  test "keeps Solr's first collation when none has its words together" do
    collation = SpellingCorrection.best_collation(solr_response("anatomy specimen", "anatomy specimens"), ->(_) { 0 })

    assert_equal "anatomy specimen", collation
  end

  test "reads extended collations and does not check a one-word collation" do
    checked = []
    collation = SpellingCorrection.best_collation(solr_response({ "collationQuery" => "anatomy" }, { "collationQuery" => "botany" }),
                                                  ->(c) { checked << c; 1 })

    assert_equal "anatomy", collation
    assert_empty checked
  end

  test "has no collation for a response without spellcheck" do
    assert_nil SpellingCorrection.best_collation({ "response" => {} }, ->(_) { 1 })
  end

  test "ignores a response that has no documents to count" do
    grouped = Struct.new(:spelling).new(Struct.new(:collation).new("anatomy"))

    assert_nil SpellingCorrection.from("anatommy", grouped)
  end
end
