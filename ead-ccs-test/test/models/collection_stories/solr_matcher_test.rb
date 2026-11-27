# frozen_string_literal: true

require "test_helper"

# The harvest's matcher: an exact accession number within one collection. Values go to Solr as {!term} parameters, never in the
# query text, and the query is parsed by the lucene parser (the default edismax ignores local params in q).
class CollectionStoriesSolrMatcherTest < ActiveSupport::TestCase
  test "the values are term-query parameters under the lucene parser, never in the query text" do
    seen = nil
    connection = Object.new
    connection.define_singleton_method(:get) do |_path, params:|
      seen = params
      { "response" => { "docs" => [ { "id" => "emu-1" } ] } }
    end

    repository = Blacklight.default_index
    repository.define_singleton_method(:connection) { connection }
    begin
      ids = CollectionStories::SolrMatcher.call("Grainger Museum Collection", 'x" OR *:*')
    ensure
      repository.singleton_class.remove_method(:connection)
    end

    assert_equal %w[emu-1], ids
    assert_equal "{!term f=accession_number_ssim v=$story_accession}", seen[:q]
    assert_equal "{!term f=collection_ssim v=$story_collection}", seen[:fq]
    assert_equal 'x" OR *:*', seen[:story_accession]
    assert_equal "lucene", seen[:defType]
  end

  test "against the core, an exact number matches its one record, and query syntax matches nothing" do
    needs_solr
    found = CollectionStories::SolrMatcher.call("Grainger Museum Collection", 'x" OR *:*')
    assert_equal [], found
  end
end
