# frozen_string_literal: true

# The home page's "On this day" (docs/categories-themes-stories.md): records made on today's day and month, when their production date
# says so ("18 November 1923", "1923-11-18"); otherwise records from this year 50, 100, 150 or 200 years ago. Only records whose picture
# a result card shows (Showcase.shown?). Kept for the day (Melbourne time); a Solr failure is kept for five minutes, so the home page
# never asks Solr more than that.
module OnThisDay
  Result = Data.define(:kind, :date, :years_ago, :documents) do
    def any? = documents.any?
  end

  SHOWN = 4
  ROWS = 40
  YEARS_AGO = [ 50, 100, 150, 200 ].freeze
  OUTAGE_TTL = 5.minutes

  def self.for(date = Time.zone.today)
    key = SuppressedRecord.cache_key("on_this_day/v1/#{date.iso8601}")
    kept = Rails.cache.read(key)
    if kept.nil?
      kept = fetch(date)
      Rails.cache.write(key, kept || {}, expires_in: kept ? (date.end_of_day.in_time_zone - Time.zone.now).clamp(60, 1.day.to_i) : OUTAGE_TTL)
    end
    return Result.new(kind: nil, date: date, years_ago: nil, documents: []) if kept.blank?

    Result.new(kind: kept["kind"].to_sym, date: date, years_ago: kept["years_ago"], documents: kept["docs"].map { |doc| SolrDocument.new(doc) })
  end

  # The Solr query for the day and month in the forms the records use. Built from the date only, never from visitor text.
  def self.day_query(date)
    month = Date::MONTHNAMES[date.month]
    forms = [ "#{date.day}\\ #{month}*", "*\\ #{date.day}\\ #{month}*", format("*-%02d-%02d*", date.month, date.day) ]
    "production_date_ssim:(#{forms.join(' OR ')})"
  end

  def self.fetch(date)
    docs = shown(SolrGuard.run { Discovery.search(q: day_query(date), rows: ROWS, sort: "id asc", fq: Categories::IMAGE_FILTERS) })
    return { "kind" => "day", "docs" => docs.first(SHOWN).map(&:_source) } if docs.any?

    years = YEARS_AGO.map { |ago| date.year - ago }
    docs = shown(SolrGuard.run { Discovery.search(q: "#{ExploreEntryPoints::DATE_FIELD}:(#{years.join(' OR ')})", rows: ROWS * 2, sort: "id asc", fq: Categories::IMAGE_FILTERS) })
    year = years.find { |candidate| docs.any? { |doc| doc["date_start_isi"].to_i == candidate } }
    return { "kind" => "none", "docs" => [] } unless year

    { "kind" => "years_ago", "years_ago" => date.year - year, "docs" => docs.select { |doc| doc["date_start_isi"].to_i == year }.first(SHOWN).map(&:_source) }
  rescue *SolrGuard::FAILURES, RSolr::Error::Http, SolrGuard::Unavailable => e
    Rails.logger.warn("On this day unavailable: #{e.class}")
    nil
  end

  def self.shown(response) = response.documents.select { |document| Showcase.shown?(document) }

  private_class_method :fetch, :shown
end
