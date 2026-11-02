# frozen_string_literal: true

require "test_helper"

class RelatedObjectsTest < ActiveSupport::TestCase
  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  def doc(fields = {}) = SolrDocument.new({ "id" => "emu-1" }.merge(fields))

  class FakeConnection
    attr_reader :params, :calls

    def initialize(docs = [], raise: nil)
      @docs = docs
      @raise = raise
      @calls = 0
    end

    def get(_path, params:)
      @params = params
      @calls += 1
      Kernel.raise @raise if @raise

      { "response" => { "docs" => @docs } }
    end
  end

  test "records that share the object type, maker, subject or place are related, and the record itself never is" do
    connection = FakeConnection.new([ { "id" => "emu-2", "title_tsim" => [ "Another harp" ] } ])
    record = doc("object_type_ssim" => [ "harp" ], "production_place_ssim" => [ "Japan" ], "creator_ssim" => [ "Yamada" ], "subject_ssim" => [ "Zithers" ])

    related = RelatedObjects.for(record, connection)

    assert_equal [ "emu-2" ], related.map(&:id)
    assert_includes connection.params[:fq], %(-id:"emu-1")
    fq = connection.params[:fq].join(" ")
    %w[harp Japan Yamada Zithers].each { |value| assert_includes fq, %("#{value}") }
    assert_equal RelatedObjects::LIMIT, connection.params[:rows]
  end

  test "an unknown maker is not a reason to relate two records" do
    connection = FakeConnection.new
    RelatedObjects.for(doc("creator_ssim" => [ "Unknown" ], "object_type_ssim" => [ "harp" ]), connection)

    assert_not_includes connection.params[:fq].join(" "), "Unknown"
  end

  test "a quote in a value cannot change the query" do
    connection = FakeConnection.new
    RelatedObjects.for(doc("object_type_ssim" => [ %(a "quoted" \\ type) ]), connection)

    assert_includes connection.params[:fq].join(" "), %(object_type_ssim:"a \\"quoted\\" \\\\ type")
  end

  test "a record with nothing to relate it by asks Solr nothing" do
    connection = FakeConnection.new

    assert_equal [], RelatedObjects.for(doc, connection)
    assert_equal 0, connection.calls
  end

  test "the answer is kept, so a busy record page does not ask Solr every time" do
    connection = FakeConnection.new([ { "id" => "emu-2" } ])
    record = doc("object_type_ssim" => [ "harp" ])

    2.times { RelatedObjects.for(record, connection) }

    assert_equal 1, connection.calls
  end

  test "Solr being unavailable gives no related records, not an error, and is not kept" do
    record = doc("object_type_ssim" => [ "harp" ])

    assert_equal [], RelatedObjects.for(record, FakeConnection.new(raise: Errno::ECONNREFUSED))

    assert_equal [ "emu-2" ], RelatedObjects.for(record, FakeConnection.new([ { "id" => "emu-2" } ])).map(&:id)
  end
end
