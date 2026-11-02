# frozen_string_literal: true

# The Search History page groups a visitor's searches by the day they were made, so a few days of searching stay easy
# to navigate (CCS-206). A day is a Melbourne day (config.time_zone).
module SearchHistoryDays
  # searches: anything with a created_at, newest first. Returns [[label, searches], ...], newest day first.
  def self.group(searches, now: Time.zone.now)
    today = now.to_date

    searches.group_by { |search| search.created_at.in_time_zone.to_date }
            .sort_by { |day, _| day }.reverse
            .map { |day, entries| [ label(day, today), entries ] }
  end

  def self.label(day, today)
    case day
    when today then "Today"
    when today - 1 then "Yesterday"
    else day.strftime("%A %-d %B %Y")
    end
  end
end
