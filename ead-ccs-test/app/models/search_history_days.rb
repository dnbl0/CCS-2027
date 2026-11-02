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

  # A search with no Digital asset choice is saved as asked, then redirected to the same search with "With a digital asset"
  # applied (SearchDefaults), which is saved too. The visitor made one search, so the one they were not shown is hidden.
  # searches: anything with query_params (Blacklight's Search rows).
  def self.without_redirected(searches)
    all = searches.map { |search| normalise(search.query_params) }

    searches.reject do |search|
      decision = SearchDefaults.decide(normalise(search.query_params), html: true, get: true, catalog: true)
      decision&.first == :search && all.include?(normalise(decision.last))
    end
  end

  # The history entries without_redirected hides for this search: the ones a default-filter redirect turned into it.
  # Deleting a search takes them out too, or they would show up in its place.
  def self.redirect_origins(searches, search)
    target = normalise(search.query_params)

    searches.select do |other|
      decision = SearchDefaults.decide(normalise(other.query_params), html: true, get: true, catalog: true)
      decision&.first == :search && normalise(decision.last) == target
    end
  end

  def self.normalise(params) = params.to_h.deep_stringify_keys

  def self.label(day, today)
    case day
    when today then "Today"
    when today - 1 then "Yesterday"
    else day.strftime("%A %-d %B %Y")
    end
  end
end
