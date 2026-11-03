# frozen_string_literal: true

require "test_helper"

class RecentlyViewedTest < ActiveSupport::TestCase
  test "the latest record comes first, and a record seen again moves to the front once" do
    viewed = RecentlyViewed.new(session = {})

    viewed.record("emu-1")
    viewed.record("emu-2")
    viewed.record("emu-1")

    assert_equal %w[emu-1 emu-2], viewed.ids
    assert_equal %w[emu-1 emu-2], session[RecentlyViewed::KEY]
  end

  test "the record being read is left out of the list shown beside it" do
    viewed = RecentlyViewed.new({})
    %w[a b c].each { |id| viewed.record(id) }

    assert_equal %w[b a], viewed.ids(except: "c")
  end

  test "only the latest records are kept, so the session cookie stays small" do
    viewed = RecentlyViewed.new({})
    (RecentlyViewed::MAX + 5).times { |n| viewed.record("emu-#{n}") }

    assert_equal RecentlyViewed::MAX, viewed.ids.size
    assert_equal "emu-#{RecentlyViewed::MAX + 4}", viewed.ids.first
  end

  test "a blank id and a damaged cookie value are ignored" do
    viewed = RecentlyViewed.new(session = { RecentlyViewed::KEY => "damaged" })

    assert_equal [], viewed.ids
    viewed.record("")
    viewed.record(nil)
    assert_equal [], viewed.ids

    session[RecentlyViewed::KEY] = [ "ok", 5, nil, { "a" => 1 } ]
    assert_equal [ "ok" ], viewed.ids
  end

  test "the documents come back in viewing order, and a record no longer indexed is dropped" do
    viewed = RecentlyViewed.new({})
    %w[a b c].each { |id| viewed.record(id) }
    connection = FakeConnection.new([ { "id" => "a" }, { "id" => "c" } ])

    documents = viewed.documents(except: nil, connection: connection)

    assert_equal %w[c a], documents.map(&:id)
    assert_equal %w[c b a].map { |id| %("#{id}") }.join(" OR ").then { |ids| "id:(#{ids})" }, connection.params[:fq]
  end

  test "nothing is asked of Solr when no record has been viewed" do
    connection = FakeConnection.new([])

    assert_equal [], RecentlyViewed.new({}).documents(except: nil, connection: connection)
    assert_nil connection.params
  end

  test "Solr being unavailable gives an empty list, not an error" do
    viewed = RecentlyViewed.new({})
    viewed.record("a")

    assert_equal [], viewed.documents(except: nil, connection: FakeConnection.new(nil, raise: Errno::ECONNREFUSED))
  end

  class FakeConnection
    attr_reader :params

    def initialize(docs, raise: nil)
      @docs = docs
      @raise = raise
    end

    def get(_path, params:)
      @params = params
      Kernel.raise @raise if @raise

      { "response" => { "docs" => @docs } }
    end
  end
end
