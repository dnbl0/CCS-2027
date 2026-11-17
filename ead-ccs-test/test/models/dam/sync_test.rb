require "test_helper"
require_relative "../../support/dam_fakes"

class DamSyncTest < ActiveSupport::TestCase
  include DamFakes

  NOW = Time.utc(2026, 11, 17, 6, 0)

  def sync(client, writer = DamFakes::Writer.new, now: NOW)
    Dam::Sync.new(client: client, writer: writer, logger: Logger.new(IO::NULL), now: -> { now })
  end

  test "a full sync reads every date window, upserts by DAM id and writes every record with an asset" do
    client = DamFakes::Client.new(->(query) { query.start_with?("lastEditDate:[1970") ? [ dam_item("a1", licence: "CC BY"), dam_item("a2", accession: "2.1") ] : [] })
    writer = DamFakes::Writer.new
    sync(client, writer).full

    assert_equal 2, DamAsset.count
    asset = DamAsset.find_by!(dam_id: "a1")
    assert_equal [ "1987.0043", "CC BY", "image" ], [ asset.accession_number, asset.licence, asset.format_type ]
    assert_equal "https://unimelbourne.widen.net/content/a1/jpeg/large.jpg", asset.urls["large"]
    assert_equal [ [ "1987.0043", "2.1" ] ], writer.written
    run = DamSyncRun.last
    assert_equal [ "full", "finished", NOW ], [ run.kind, run.status, run.checkpoint ]
    assert_operator client.queries.size, :>, 100, "a month at a time since 2010"
    assert_equal Dam::Client.edited_between(Time.utc(1970, 1, 1), Dam::Sync::EPOCH), client.queries.first
  end

  test "running it again updates rows in place" do
    sync(DamFakes::Client.new(any: [ dam_item("a1", licence: "") ])).full
    sync(DamFakes::Client.new(any: [ dam_item("a1", licence: "Individual") ])).full(resume: false)

    assert_equal 1, DamAsset.count
    assert_equal "Individual", DamAsset.sole.licence
  end

  test "a full run that stopped resumes after the last window it finished" do
    checkpoint = Time.utc(2026, 9, 1)
    DamSyncRun.create!(kind: "full", status: "failed", started_at: NOW - 1.hour, checkpoint: checkpoint)
    client = DamFakes::Client.new(any: [])
    sync(client).full

    assert_equal [ "#{Dam::Client.edited_between(checkpoint, checkpoint.next_month)}" ], client.queries.first(1)
    assert_equal 1, DamSyncRun.count
    assert_equal "finished", DamSyncRun.sole.status
  end

  test "a failure marks the run failed, so the next run resumes it" do
    failing = Object.new
    def failing.count(_query) = 0
    def failing.each_page(**) = raise(Dam::Error, "the DAM was still failing")
    assert_raises(Dam::Error) { sync(failing).full }

    assert_equal "failed", DamSyncRun.sole.status
    assert_match "still failing", DamSyncRun.sole.error
  end

  test "an incremental sync reads what changed since the last run started, and rewrites the old and new records of a moved asset" do
    DamSyncRun.create!(kind: "full", status: "finished", started_at: NOW - 1.hour, finished_at: NOW - 30.minutes)
    DamAsset.create!(dam_id: "a1", accession_number: "OLD.1")
    client = DamFakes::Client.new(any: [ dam_item("a1", accession: "NEW.1") ])
    writer = DamFakes::Writer.new
    sync(client, writer).incremental

    assert_equal [ Dam::Client.edited_between(NOW - 1.hour - Dam::Sync::OVERLAP, NOW) ], client.queries
    assert_equal [ [ "NEW.1", "OLD.1" ] ], writer.written
    assert_equal "NEW.1", DamAsset.sole.accession_number
  end

  test "an incremental sync before any full one asks for a full one" do
    error = assert_raises(Dam::Error) { sync(DamFakes::Client.new(any: [])).incremental }
    assert_match "FULL=1", error.message
  end

  test "a reconcile marks the assets the DAM no longer lists as deleted and rewrites their records" do
    %w[a1 a2 a3 a4 a5 a6 a7 a8 a9 a10].each_with_index { |id, i| DamAsset.create!(dam_id: id, accession_number: "N.#{i}") }
    listed = (1..9).map { |n| { "id" => "a#{n}" } }
    writer = DamFakes::Writer.new
    sync(DamFakes::Client.new(any: listed), writer).reconcile

    assert_equal NOW, DamAsset.find_by!(dam_id: "a10").deleted_at
    assert_equal 9, DamAsset.live.count
    assert_equal [ [ "N.9" ] ], writer.written
  end

  test "a range with more assets than offset paging can read is halved until each part fits, in time order" do
    month = Dam::Client.edited_between(Time.utc(2026, 10, 1), Time.utc(2026, 11, 1))
    counts = ->(query) { query == month ? Dam::Sync::MAX_RANGE + 1 : 0 }
    client = DamFakes::Client.new({ any: [] }, counts: counts)
    sync(client, now: Time.utc(2026, 11, 1)).full

    halves = [ [ Time.utc(2026, 10, 1), Time.utc(2026, 10, 16, 12) ], [ Time.utc(2026, 10, 16, 12), Time.utc(2026, 11, 1) ] ]
    assert_equal halves.map { |from, to| Dam::Client.edited_between(from, to) }, client.queries.last(2)
    assert_not_includes client.queries, month
  end

  # A client whose first sort order returns a tied asset twice and misses another, as the DAM did on 2026-11-17
  def tied_client(orders)
    sorts = []
    client = Object.new
    client.define_singleton_method(:count) { |_query| 3 }
    client.define_singleton_method(:each_page) do |query:, expand: true, sort: nil, &block|
      sorts << sort
      items = orders.fetch(sort, orders.values.last)
      block.call(items, items.size, 3)
      3
    end
    [ client, sorts ]
  end

  test "a range that comes back short (tied creation times) is read again in the next sort order and the reads merged" do
    client, sorts = tied_client("created_date" => [ dam_item("a1"), dam_item("a2"), dam_item("a2") ],
                                "-created_date" => [ dam_item("a3"), dam_item("a2"), dam_item("a1") ])
    DamSyncRun.create!(kind: "full", status: "finished", started_at: NOW - 1.hour)
    sync(client).incremental

    assert_equal %w[created_date -created_date], sorts
    assert_equal %w[a1 a2 a3], DamAsset.order(:dam_id).pluck(:dam_id)
  end

  test "a range short in every sort order fails the run, to be resumed" do
    client, sorts = tied_client("created_date" => [ dam_item("a1"), dam_item("a1"), dam_item("a1") ])
    DamSyncRun.create!(kind: "full", status: "finished", started_at: NOW - 1.hour)

    assert_raises(Dam::Client::ShortRead) { sync(client).incremental }
    assert_equal Dam::Client::SORTS, sorts
    assert_equal "failed", DamSyncRun.order(:id).last.status
  end

  test "a reconcile that lists far fewer assets than are live marks nothing deleted" do
    %w[a1 a2 a3].each { |id| DamAsset.create!(dam_id: id) }
    assert_raises(Dam::Error) { sync(DamFakes::Client.new(any: [ { "id" => "a1" } ])).reconcile }

    assert_equal 3, DamAsset.live.count
  end
end
