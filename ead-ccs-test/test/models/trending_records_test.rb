require "test_helper"
require_relative "../support/discovery_records"
require_relative "../support/env_override"

class TrendingRecordsTest < ActiveSupport::TestCase
  include DiscoveryRecords
  include EnvOverride

  setup do
    RecordView.reset_pending!
    RecordView.delete_all
    @records = (1..6).map { |n| open_record("emu-#{n}") }
  end

  def view(id, views, day: Date.current) = RecordView.create!(document_id: id, day: day, views: views)

  test "the most viewed come first" do
    view("emu-1", 4)
    view("emu-2", 9)
    view("emu-3", 6)

    with_canned_search(discovery_solr(records: @records)) do
      assert_equal %w[emu-2 emu-3 emu-1], TrendingRecords.documents(limit: 6).map(&:id)
    end
  end

  test "thin data gives nothing, so the page shows Featured alone" do
    view("emu-1", 4)
    view("emu-2", 9)
    view("emu-3", 2) # under the minimum views

    with_canned_search(discovery_solr(records: @records)) { assert_equal [], TrendingRecords.documents }
  end

  test "a record that is withheld or sensitive now is left out even if it was counted before" do
    view("emu-1", 4)
    view("emu-2", 9)
    view("emu-3", 6)
    view("emu-4", 20)
    records = [ open_record("emu-1"), open_record("emu-2"), open_record("emu-3"), withheld_record("emu-4") ]

    with_canned_search(discovery_solr(records: records)) do
      assert_equal %w[emu-2 emu-3 emu-1], TrendingRecords.documents.map(&:id)
    end
  end

  test "off means nothing, and a failing database or Solr means nothing" do
    3.times { |n| view("emu-#{n + 1}", 5) }
    with_canned_search(discovery_solr(records: @records)) do
      with_env("TRENDING_ENABLED" => "off") { assert_equal [], TrendingRecords.documents }
    end
    with_canned_search(->(_params) { raise Faraday::TimeoutError }) { assert_equal [], TrendingRecords.documents }
    original = RecordView.method(:top)
    RecordView.define_singleton_method(:top) { |**| raise ActiveRecord::ConnectionNotEstablished }
    with_canned_search(discovery_solr(records: @records)) { assert_equal [], TrendingRecords.documents }
  ensure
    RecordView.define_singleton_method(:top, &original) if original
  end
end
