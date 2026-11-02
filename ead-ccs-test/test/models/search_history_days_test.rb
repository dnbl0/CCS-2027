require "test_helper"

class SearchHistoryDaysTest < ActiveSupport::TestCase
  Entry = Struct.new(:created_at)

  def now = Time.zone.local(2026, 11, 4, 15, 30)

  test "searches are grouped by the day they were made, newest day first" do
    today = Entry.new(Time.zone.local(2026, 11, 4, 9))
    earlier_today = Entry.new(Time.zone.local(2026, 11, 4, 1))
    yesterday = Entry.new(Time.zone.local(2026, 11, 3, 23, 59))
    last_week = Entry.new(Time.zone.local(2026, 10, 28, 12))

    groups = SearchHistoryDays.group([ today, earlier_today, yesterday, last_week ], now: now)

    assert_equal [ "Today", "Yesterday", "Wednesday 28 October 2026" ], groups.map(&:first)
    assert_equal [ [ today, earlier_today ], [ yesterday ], [ last_week ] ], groups.map(&:last)
  end

  test "the order within a day is the order the searches were given" do
    newer = Entry.new(Time.zone.local(2026, 11, 4, 12))
    older = Entry.new(Time.zone.local(2026, 11, 4, 8))

    assert_equal [ newer, older ], SearchHistoryDays.group([ newer, older ], now: now).first.last
  end

  test "a day is a Melbourne day, not a UTC one" do
    just_after_midnight = Entry.new(Time.zone.local(2026, 11, 4, 0, 30)) # still 3 November in UTC

    assert_equal [ "Today" ], SearchHistoryDays.group([ just_after_midnight ], now: now).map(&:first)
  end

  test "no searches, no groups" do
    assert_empty SearchHistoryDays.group([], now: now)
  end
end
