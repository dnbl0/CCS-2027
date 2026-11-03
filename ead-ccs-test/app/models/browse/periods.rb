# frozen_string_literal: true

module Browse
  # Centuries and decades of date_start_isi (the year a record's date begins; 28,264 of 40,962 records have one). A period is a
  # span of whole years named by its address, the same spans as the browse page of periods (BrowseHubs.periods):
  #
  #   before-1000   everything earlier than the year 1000 (BCE years are negative; 1,454 records)
  #   1000-1099     a century (1000 to 1799 in the periods list; 1800 on, its decades are listed and the century is one click up)
  #   1920-1929     a decade
  #
  # The span is read from the address, so a period needs no lookup; an address that is not one of these is not a period.
  Period = Data.define(:first, :last, :kind) do
    def slug = kind == :before ? "before-#{Periods::FIRST_CENTURY}" : "#{first}-#{last}"
    def path = Rails.application.routes.url_helpers.browse_period_path(slug: slug)
    def label = kind == :before ? I18n.t("browse.period.before", year: Periods::FIRST_CENTURY) : "#{first}–#{last}"
    def span = label
    def fq = kind == :before ? "#{Periods::FIELD}:[* TO #{last}]" : "#{Periods::FIELD}:[#{first} TO #{last}]"

    # The search of the same records (the range filter of the results page)
    def search_query
      { any_assets: "1", search_field: "all_fields", range: { Periods::FIELD => kind == :before ? { end: last } : { begin: first, end: last } } }
    end

    def parent = kind == :decade ? Periods.century(first) : nil
  end

  module Periods
    FIELD = "date_start_isi"
    FIRST_CENTURY = 1000
    LATEST_YEAR = 2100

    # nil for an address that is not a period
    def self.parse(slug)
      slug = slug.to_s
      return before if slug == "before-#{FIRST_CENTURY}"

      match = slug.match(/\A(\d{4})-(\d{4})\z/) or return
      from = match[1].to_i
      to = match[2].to_i
      return if from < FIRST_CENTURY || from >= LATEST_YEAR

      if (from % 100).zero? && to == from + 99 then Period.new(from, to, :century)
      elsif (from % 10).zero? && to == from + 9 then Period.new(from, to, :decade)
      end
    end

    # The period of the span BrowseHubs lists ("Before 1000" starts at -10,000)
    def self.for_span(first, last) = last == FIRST_CENTURY - 1 ? before : parse("#{first}-#{last}")

    def self.before = Period.new(nil, FIRST_CENTURY - 1, :before)
    def self.century(year) = Period.new(year / 100 * 100, (year / 100 * 100) + 99, :century)
    def self.decade(year) = Period.new(year / 10 * 10, (year / 10 * 10) + 9, :decade)

    # The period a facet.range key (its start year) stands for, with gap 100 or 10
    def self.for_range_start(start, gap)
      return before if start < FIRST_CENTURY

      gap == 10 ? decade(start) : century(start)
    end
  end
end
