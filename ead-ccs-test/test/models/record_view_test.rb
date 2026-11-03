require "test_helper"
require_relative "../support/env_override"

# Trending's counter (docs/similar-and-trending.md): aggregate, anonymous, cheap to write.
class RecordViewTest < ActiveSupport::TestCase
  include EnvOverride

  setup do
    RecordView.reset_pending!
    RecordView.delete_all
  end

  teardown { RecordView.reset_pending! }

  test "the table holds a record, a day and a number, and nothing that could identify a visitor" do
    assert_equal %w[day document_id id views], RecordView.column_names.sort,
                 "a new column on record_views must not hold personal data (cookie, session, IP address, user agent, user); update privacy and docs/compliance-register.md first"
  end

  test "views are held in memory and written together, adding to the day's count" do
    3.times { RecordView.record("emu-1") }
    RecordView.record("emu-2")
    assert_equal 0, RecordView.count, "nothing is written until a flush"

    assert_equal 2, RecordView.flush
    assert_equal({ "emu-1" => 3, "emu-2" => 1 }, RecordView.pluck(:document_id, :views).to_h)

    2.times { RecordView.record("emu-1") }
    RecordView.flush
    assert_equal 5, RecordView.find_by!(document_id: "emu-1", day: Date.current).views
    assert_equal 0, RecordView.flush
  end

  test "the counts are written at once when many different records are waiting" do
    RecordView::FLUSH_AT.times { |n| RecordView.record("emu-#{n}") }

    assert_equal RecordView::FLUSH_AT, RecordView.count
    assert_empty RecordView.pending_counts
  end

  test "a failed write drops the waiting counts and does not raise" do
    RecordView.record("emu-1")
    original = RecordView.method(:upsert_all)
    RecordView.define_singleton_method(:upsert_all) { |*, **| raise ActiveRecord::StatementInvalid, "database is down" }
    assert_equal 0, RecordView.flush

    assert_empty RecordView.pending_counts
  ensure
    RecordView.define_singleton_method(:upsert_all, &original) if original
  end

  test "nothing is counted when Trending is off, or for an id that is empty or too long" do
    with_env("TRENDING_ENABLED" => "off") { RecordView.record("emu-1") }
    RecordView.record("")
    RecordView.record("x" * (RecordView::MAX_ID_LENGTH + 1))

    assert_empty RecordView.pending_counts
  end

  test "trending is the most viewed in the window, with at least the minimum views" do
    today = Date.current
    RecordView.create!(document_id: "a", day: today, views: 5)
    RecordView.create!(document_id: "a", day: today - 3, views: 4)
    RecordView.create!(document_id: "b", day: today - 1, views: 6)
    RecordView.create!(document_id: "c", day: today, views: 2)          # under the minimum of 3
    RecordView.create!(document_id: "d", day: today - 7, views: 50)     # outside a 7-day window (today and the 6 days before)

    assert_equal [ [ "a", 9 ], [ "b", 6 ] ], RecordView.top(days: 7, limit: 10, min: 3)
    assert_equal [ [ "a", 9 ] ], RecordView.top(days: 7, limit: 1, min: 3)
    assert_equal [ [ "d", 50 ], [ "a", 9 ], [ "b", 6 ] ], RecordView.top(days: 8, limit: 10, min: 3)
  end

  test "the window and the minimum come from the environment, within sane limits" do
    assert_equal 7, RecordView.window_days
    assert_equal 3, RecordView.min_views
    with_env("TRENDING_DAYS" => "14", "TRENDING_MIN_VIEWS" => "10") do
      assert_equal 14, RecordView.window_days
      assert_equal 10, RecordView.min_views
    end
    with_env("TRENDING_DAYS" => "9999", "TRENDING_MIN_VIEWS" => "nonsense") do
      assert_equal 90, RecordView.window_days
      assert_equal 3, RecordView.min_views
    end
  end

  test "prune removes the days before the keep window" do
    RecordView.create!(document_id: "old", day: Date.current - 40, views: 1)
    RecordView.create!(document_id: "new", day: Date.current - 2, views: 1)

    assert_equal 1, RecordView.prune(days: 35)
    assert_equal [ "new" ], RecordView.pluck(:document_id)
  end
end
