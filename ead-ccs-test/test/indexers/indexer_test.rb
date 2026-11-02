require "test_helper"
require_relative "../support/env_override"

# CCS-149: characterisation tests for Collections::Indexer, with a stand-in for Solr so nothing is written to a real core.
class IndexerTest < ActiveSupport::TestCase
  include EnvOverride

  class FakeSolr
    attr_reader :added, :commits, :deleted_by_query

    def initialize(count: 0)
      @added = []
      @commits = 0
      @deleted_by_query = []
      @count = count
    end

    def add(documents) = @added << documents.dup
    def commit = @commits += 1
    def delete_by_query(query) = @deleted_by_query << query
    def get(_path, params: {}) = { "response" => { "numFound" => @count } }
  end

  # A source that hands over the documents it was given
  class ListSource
    attr_reader :name, :path

    def initialize(name, documents)
      @name = name
      @documents = documents
      @path = "#{name}.csv"
    end

    def each_document(&) = @documents.each(&)
  end

  def indexer(solr, batch_size: 2)
    log = StringIO.new
    Collections::Indexer.new(batch_size: batch_size, logger: Logger.new(log)).tap do |indexer|
      indexer.define_singleton_method(:solr) { solr }
      indexer.define_singleton_method(:log) { log.string }
    end
  end

  test "documents are sent in batches of the batch size and committed once at the end" do
    solr = FakeSolr.new
    result = indexer(solr).index(ListSource.new("emu", (1..5).map { |n| { "id" => "emu-#{n}" } }))

    assert_equal [ 2, 2, 1 ], solr.added.map(&:size)
    assert_equal 1, solr.commits
    assert_equal({ indexed: 5, duplicate_ids: 0 }, result)
  end

  test "an id that two sources share is counted and logged, and both documents are still sent" do
    solr = FakeSolr.new
    sources = [ ListSource.new("emu", [ { "id" => "x-1" } ]), ListSource.new("vernon", [ { "id" => "x-1" }, { "id" => "x-2" } ]) ]
    subject = indexer(solr)
    result = subject.index(sources)

    assert_equal({ indexed: 3, duplicate_ids: 1 }, result)
    assert_match(/duplicate id x-1 \(also in emu\)/, subject.log)
    assert_match(/1 duplicate ids -- indexed fewer documents than rows/, subject.log)
  end

  test "nothing to index still commits, and a single source need not be in an array" do
    solr = FakeSolr.new

    assert_equal({ indexed: 0, duplicate_ids: 0 }, indexer(solr).index([]))
    assert_equal 1, solr.commits
    assert_equal({ indexed: 1, duplicate_ids: 0 }, indexer(solr).index(ListSource.new("emu", [ { "id" => "a" } ])))
  end

  test "clear deletes every document and commits, and document_count reads numFound" do
    solr = FakeSolr.new(count: 41)
    subject = indexer(solr)
    subject.clear

    assert_equal [ "*:*" ], solr.deleted_by_query
    assert_equal 1, solr.commits
    assert_equal 41, subject.document_count
  end

  test "the Solr address is SOLR_URL, or the local default" do
    with_env("SOLR_URL" => "http://solr.example:8983/solr/core") { assert_equal "http://solr.example:8983/solr/core", Collections::Indexer.default_solr_url }
    with_env("SOLR_URL" => nil) { assert_equal "http://127.0.0.1:8983/solr/blacklight-core", Collections::Indexer.default_solr_url }
  end

  test "it connects to Solr lazily, once, at the address it was given" do
    subject = Collections::Indexer.new(solr_url: "http://127.0.0.1:9/solr/none", logger: Logger.new(nil))

    assert_same subject.solr, subject.solr
  end
end
