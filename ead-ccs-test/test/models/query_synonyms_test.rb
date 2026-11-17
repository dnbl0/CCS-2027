# frozen_string_literal: true

require "test_helper"

# Query-time synonyms from config/synonyms.yml (QuerySynonyms), applied by the SearchBuilder: no Solr schema change or reload. The
# example pair is the test's own; the real list is the collections team's to supply.
class QuerySynonymsTest < ActiveSupport::TestCase
  EXAMPLE = [ [ "skull", "cranium" ], [ "aboriginal bark painting", "bark painting" ] ].freeze

  def with_synonyms(groups = EXAMPLE)
    QuerySynonyms.use(groups)
    yield
  ensure
    QuerySynonyms.use(nil)
  end

  def built(params) = SearchBuilder.new(CatalogController.new).with(params).to_h

  test "the shipped list is empty, with a note saying who supplies the terms" do
    assert_equal [], QuerySynonyms.load_file(Rails.root.join("config/synonyms.yml"))
    assert_match(/collections team/i, File.read(Rails.root.join("config/synonyms.yml")))
  end

  test "the visitor's words come first, then each version with a word swapped for a synonym; phrases count as one term" do
    with_synonyms do
      assert_equal [ "skull human", "cranium human" ], QuerySynonyms.versions("skull human")
      assert_equal [ "human Cranium", "human skull" ], QuerySynonyms.versions("human Cranium")
      assert_equal [ "bark painting Arnhem", "aboriginal bark painting Arnhem" ], QuerySynonyms.versions("bark painting Arnhem")
      assert_equal [ "skull skull", "skull cranium", "cranium skull", "cranium cranium" ], QuerySynonyms.versions("skull skull")
    end
  end

  test "a whole word only, never part of one, and a query with nothing to swap is just itself" do
    with_synonyms do
      assert_equal [ "skulls" ], QuerySynonyms.versions("skulls")
      assert_equal [ "portrait" ], QuerySynonyms.versions("portrait")
    end
  end

  test "no more than eight versions" do
    with_synonyms([ %w[a1 a2 a3], %w[b1 b2 b3], %w[c1 c2 c3] ]) { assert_equal 8, QuerySynonyms.versions("a1 b1 c1").size }
  end

  # The edismax clauses Solr is sent: the versions, inside a bool "should"
  def sent(params)
    return [ params[:q] ] if params[:q]

    must = params[:json].with_indifferent_access.dig(:query, :bool, :must).first
    must[:edismax] ? [ must.dig(:edismax, :query) ] : must.dig(:bool, :should).map { |clause| clause.with_indifferent_access.dig(:edismax, :query) }
  end

  test "the SearchBuilder sends any of the versions, keeps the keyword match rule and the search field's settings, and spellchecks the visitor's words" do
    with_synonyms do
      [ { q: "skull human", search_field: "all_fields" }, { q: "skull human" } ].each do |request|
        params = built(request)
        assert_equal [ "skull human", "cranium human" ], sent(params), request.inspect
        assert_equal SearchBuilder::KEYWORD_MM, params[:mm]
        assert_equal "skull human", params["spellcheck.q"]
      end

      title = built(q: "skull", search_field: "title")
      clause = title[:json].with_indifferent_access.dig(:query, :bool, :must).first.dig(:bool, :should).last[:edismax]
      assert_equal "${title_qf}", clause[:qf]
      assert_equal "cranium", clause[:query]
    end
  end

  test "a query written with operators, a quoted phrase or a field is the visitor's own and is left alone" do
    with_synonyms do
      [ "skull OR bone", %("skull of a cat"), "title_tsim:skull", "+skull" ].each do |query|
        assert_equal [ query ], sent(built(q: query, search_field: "all_fields")), query
      end
    end
  end

  test "with no synonyms nothing changes" do
    with_synonyms([]) { assert_equal [ "skull" ], sent(built(q: "skull", search_field: "all_fields")) }
  end
end
