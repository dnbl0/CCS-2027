# frozen_string_literal: true

module Browse
  # Centuries and decades of date_start_isi (the year a record's date begins; 28,264 of 40,962 records have one, and 1,403 of
  # those are BCE, stored as negative years). A period is a span of years, named by its address:
  #
  #   1900-1999          century (CE: 0-99, 100-199 ... 2000-2099), shown as "1900s"
  #   1920-1929          decade, shown as "1920s" (1900-1909 is shown as "1900-1909", as "1900s" is the century)
  #   bce-500-401        BCE century (-500 to -401), shown as "500-401 BCE"
  #   before-5000-bce    everything earlier than 5000 BCE, one period
  #
  # The span is read from the address, so a period needs no lookup; an address that is not one of these is not a period.
  Period = Data.define(:first, :last, :kind) do
    def slug
      case kind
      when :before then "before-#{-Periods::EARLIEST_CENTURY}-bce"
      when :bce_century then "bce-#{-first}-#{-last}"
      else "#{first}-#{last}"
      end
    end

    def path = Rails.application.routes.url_helpers.browse_period_path(slug: slug)

    def label
      case kind
      when :before then I18n.t("browse.time.before", year: Browse.year(Periods::EARLIEST_CENTURY))
      when :bce_century then "#{-first}–#{-last} BCE"
      when :decade then (first % 100).zero? ? "#{first}–#{last}" : "#{first}s"
      else first >= 1000 ? "#{first}s" : "#{first}–#{last} CE"
      end
    end

    # The span in words, for a century shown as "1900s"
    def span = kind == :before ? label : "#{Browse.year(first)}–#{Browse.year(last)}"

    def fq = kind == :before ? "#{Periods::FIELD}:[* TO #{last}]" : "#{Periods::FIELD}:[#{first} TO #{last}]"

    # The search of the same records (the range filter of the results page)
    def search_query
      { any_assets: "1", search_field: "all_fields", range: { Periods::FIELD => kind == :before ? { end: last } : { begin: first, end: last } } }
    end

    def parent = kind == :decade ? Periods.century(first) : nil
  end

  module Periods
    FIELD = "date_start_isi"
    EARLIEST_CENTURY = -5000 # older records share one period
    LATEST_YEAR = 2100
    DECADES_FROM = 1700      # the time hub lists decades from here; a century page lists its own

    # nil for an address that is not a period
    def self.parse(slug)
      slug = slug.to_s
      case slug
      when "before-#{-EARLIEST_CENTURY}-bce" then before
      when /\Abce-(\d{3,4})-(\d{1,4})\z/
        from = Regexp.last_match(1).to_i
        to = Regexp.last_match(2).to_i
        Period.new(-from, -to, :bce_century) if (from % 100).zero? && to == from - 99 && from <= -EARLIEST_CENTURY
      when /\A(\d{1,4})-(\d{1,4})\z/
        from = Regexp.last_match(1).to_i
        to = Regexp.last_match(2).to_i
        return if from >= LATEST_YEAR

        if (from % 100).zero? && to == from + 99 then Period.new(from, to, :century)
        elsif (from % 10).zero? && to == from + 9 then Period.new(from, to, :decade)
        end
      end
    end

    def self.before = Period.new(nil, EARLIEST_CENTURY - 1, :before)
    def self.century(year) = Period.new(year / 100 * 100, (year / 100 * 100) + 99, :century)
    def self.decade(year) = Period.new(year / 10 * 10, (year / 10 * 10) + 9, :decade)

    # The century or decade a start year falls in, as a Period (BCE years in their BCE century)
    def self.bce_century(year) = Period.new(year.floor(-2), year.floor(-2) + 99, :bce_century)

    # The period that the key of a facet.range (its start year) stands for, with gap 100 or 10
    def self.for_range_start(start, gap)
      return before if start < EARLIEST_CENTURY

      if gap == 10 then decade(start)
      elsif start.negative? then bce_century(start)
      else century(start)
      end
    end

    # Records with a start year in each century (and each decade from DECADES_FROM), and before the earliest: one Solr request,
    # cached. [[Period, count], ...] in time order, only periods with records.
    Counts = Data.define(:centuries, :decades, :before)

    def self.counts(repository: nil)
      Rails.cache.fetch("browse/periods/v1", expires_in: CACHE_TTL, skip_nil: true) { fetch_counts(repository || Blacklight.default_index) }
    end

    def self.fetch_counts(repository)
      response = repository.search(params: { q: "*:*", rows: 0, facet: true, "json.nl": "map", qt: "select", defType: "lucene",
                                             "facet.range": FIELD, "facet.mincount": 1,
                                             "facet.range.start": EARLIEST_CENTURY, "facet.range.end": LATEST_YEAR,
                                             "facet.range.gap": 100, "facet.range.other": "before" })
      centuries = Facets.range(response, FIELD).map { |start, count| [ for_range_start(start, 100), count ] }.sort_by { |period, _| period.first }
      earlier = Facets.before(response, FIELD)
      centuries.unshift([ before, earlier ]) if earlier.positive?
      Counts.new(centuries, decades(repository), earlier)
    end

    def self.decades(repository)
      response = repository.search(params: { q: "*:*", rows: 0, facet: true, "json.nl": "map", qt: "select", defType: "lucene",
                                             "facet.range": FIELD, "facet.mincount": 1,
                                             "facet.range.start": DECADES_FROM, "facet.range.end": 2040, "facet.range.gap": 10 })
      Facets.range(response, FIELD).map { |start, count| [ decade(start), count ] }.sort_by { |period, _| period.first }
    end
    private_class_method :fetch_counts, :decades
  end
end
