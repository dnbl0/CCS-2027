# frozen_string_literal: true

# The day-by-day count of views of each record page, for Trending (docs/similar-and-trending.md). A row is a record id, a day and
# a number; nothing about the visitor is kept (no cookie, IP address, user agent or session), so the table holds no personal
# data (test/models/record_view_test.rb checks its columns).
#
# Cheap writes. A view is added to a counter in this process's memory (a Mutex-guarded Hash), and the counters are written in
# one INSERT ... ON CONFLICT DO UPDATE statement every FLUSH_SECONDS, or sooner when FLUSH_AT different records are waiting, or when
# the process exits. So a record page asks the database for nothing on most requests. With several processes each has its own
# counters and they add up in the table. A process that is killed loses at most the last minute of its counts, which is acceptable
# for "most viewed this week". A database error on a flush drops those counts (logged) rather than breaking the page.
#
# Which views count is decided by the caller (CountsRecordViews: a human-looking request for a record that Discovery lists).
class RecordView < ApplicationRecord
  FLUSH_SECONDS = 60
  FLUSH_AT = 200
  MAX_ID_LENGTH = 200
  LOCK = Mutex.new

  class << self
    # Trending is on unless TRENDING_ENABLED is "off"
    def enabled? = BotControls.on?("TRENDING_ENABLED", true)

    # The window of "most viewed in the last N days" (TRENDING_DAYS, 1 to 90, default 7)
    def window_days = bounded(ENV.fetch("TRENDING_DAYS", 7), 7, 1..90)

    # A record needs at least this many views in the window to be called trending (TRENDING_MIN_VIEWS, default 3)
    def min_views = bounded(ENV.fetch("TRENDING_MIN_VIEWS", 3), 3, 1..1000)

    # Rows older than this many days are removed by prune (TRENDING_KEEP_DAYS, default 35: longer than any window)
    def keep_days = bounded(ENV.fetch("TRENDING_KEEP_DAYS", 35), 35, 1..365)

    # Adds one view of the record on `day`. Returns nothing; never raises.
    def record(document_id, day: Date.current)
      id = document_id.to_s
      return unless enabled? && id.present? && id.length <= MAX_ID_LENGTH

      LOCK.synchronize do
        pending[[ day, id ]] += 1
        due = pending.size >= FLUSH_AT || monotonic_now - @last_flush >= FLUSH_SECONDS
        flush_locked if due
      end
    end

    # Writes the waiting counts to the table. Returns the number of records written.
    def flush = LOCK.synchronize { flush_locked }

    # Counts waiting in memory (tests)
    def pending_counts = LOCK.synchronize { pending.dup }

    # Forgets the waiting counts without writing them (tests)
    def reset_pending! = LOCK.synchronize { @pending = Hash.new(0) }

    # [[document_id, views], ...] for the most viewed records of the last `days` days (today included), most first, each with at
    # least `min` views. At most `limit` rows.
    def top(days: window_days, limit: 12, min: min_views)
      since = Date.current - (days - 1)
      where(day: since..).group(:document_id).having("SUM(views) >= ?", min).order(Arel.sql("SUM(views) DESC, document_id ASC"))
        .limit(limit).sum(:views).to_a
    end

    # Removes the days before the last `days`. Returns the number of rows removed.
    def prune(days: keep_days) = where(day: ...(Date.current - days)).delete_all

    private

    def bounded(setting, default, range)
      value = Integer(setting, exception: false) || default
      value.clamp(range.min, range.max)
    end

    def pending = (@pending ||= Hash.new(0))

    def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def flush_locked
      @last_flush = monotonic_now
      rows = pending.map { |(day, id), views| { document_id: id, day: day, views: views } }
      pending.clear
      return 0 if rows.empty?

      upsert_all(rows, unique_by: %i[day document_id], on_duplicate: Arel.sql("views = record_views.views + EXCLUDED.views"))
      rows.size
    rescue StandardError => error
      Rails.logger.warn("Trending counts not saved: #{error.class}: #{error.message}")
      0
    end
  end

  @last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  at_exit { flush }
end
