# frozen_string_literal: true

module Explore
  # The "explore by time" page (/explore/time, docs/time-and-place.md): the record counts of every century of date_start_isi (BCE
  # years are negative), or of the decades of one century, each with a few pictures, and the eras of date_era_ssim. Two Solr
  # requests (counts, then pictures for the periods that have records), cached. Every period opens /catalog with the year range filter.
  class Timeline
    FIELD = "date_start_isi"
    ERA_FIELD = "date_era_ssim"
    EARLIEST = -3000 # centuries from 3000 BCE; anything earlier is one "before" period
    IMAGES = 3
    THUMBNAIL_FILTERS = [ "thumbnail_path_ssi:*", "has_digital_asset_bsi:true", "-restrictions_tsi:sensitive" ].freeze

    Image = Data.define(:id, :title, :src)

    Period = Data.define(:first, :last, :count, :images) do
      def before? = first.nil?
      def century? = !before? && last - first == 99
      def key = before? ? "before" : first.to_s
      def fq = before? ? "#{FIELD}:[* TO #{last}]" : "#{FIELD}:[#{first} TO #{last}]"

      def label
        return I18n.t("explore_pages.time.before", year: Timeline.year(last + 1)) if before?
        last.negative? ? "#{first.abs}–#{last.abs} BCE" : "#{first}–#{last}"
      end

      # The strip's short name: a century by its first year ("1900s", "500s BCE"), the earliest period "Earlier"
      def short_label
        return I18n.t("explore_pages.time.earlier") if before?
        first.negative? ? "#{first.abs}s BCE" : "#{first}s"
      end

      def search_query
        range = before? ? { end: last } : { begin: first, end: last }
        { any_assets: "1", search_field: "all_fields", range: { FIELD => range } }
      end
    end

    Era = Data.define(:name, :count) do
      def search_query = { any_assets: "1", search_field: "all_fields", f: { ERA_FIELD => [ name ] } }
    end

    Result = Data.define(:periods, :eras, :century)

    # century: a century's first year (1900, -500) to show its decades; nil for every century
    def self.call(century: nil, connection: nil, this_year: Time.zone.today.year)
      Cache.fetch("timeline/#{century || 'all'}") { new(connection, this_year).build(century) }
    end

    # A whole century, or nil (the page then shows every century)
    def self.century_param(value, this_year: Time.zone.today.year)
      year = Integer(value.to_s, exception: false)
      year if year && (year % 100).zero? && year >= EARLIEST && year <= this_year
    end

    def self.year(year) = year.negative? ? "#{year.abs} BCE" : year.to_s

    # "5th century BC" before "20th century"; names that say no century last, in alphabetical order
    def self.era_order(name)
      match = name.to_s.match(/(\d+)(?:st|nd|rd|th)\s+(century|millennium)(.*)/i)
      return [ 1, 0, name.to_s.downcase ] unless match

      number = match[1].to_i * (match[2].casecmp?("millennium") ? 10 : 1)
      [ 0, match[3].match?(/\bB\.?C/i) ? -number : number, name.to_s.downcase ]
    end

    def initialize(connection, this_year)
      @connection = connection
      @this_year = this_year
    end

    def build(century)
      response = Cache.get(@connection, count_params(century))
      periods = ranges(response, century)
      periods = with_images(periods) if periods.any?
      eras = century ? [] : Browse::Facets.pairs(response, ERA_FIELD).reject { |name, _| Browse.noise?(name) }.map { |name, count| Era.new(name, count) }
      Result.new(periods: periods, eras: eras.sort_by { |era| self.class.era_order(era.name) }, century: century)
    end

    private

    def count_params(century)
      start, finish, gap = century ? [ century, century + 100, 10 ] : [ EARLIEST, ((@this_year / 100) + 1) * 100, 100 ]
      params = { q: "*:*", rows: 0, wt: "json", facet: true, "facet.range": FIELD, "f.#{FIELD}.facet.range.start": start,
                 "f.#{FIELD}.facet.range.end": finish, "f.#{FIELD}.facet.range.gap": gap, "f.#{FIELD}.facet.mincount": 1 }
      return params if century

      params.merge("f.#{FIELD}.facet.range.other": "before", "facet.field": ERA_FIELD, "f.#{ERA_FIELD}.facet.limit": -1, "f.#{ERA_FIELD}.facet.mincount": 1)
    end

    def ranges(response, century)
      gap = century ? 9 : 99
      periods = Browse::Facets.range(response, FIELD).select { |_start, count| count.positive? }.sort.map do |start, count|
        Period.new(first: start, last: start + gap, count: count, images: [])
      end
      before = Browse::Facets.before(response, FIELD)
      century || before.zero? ? periods : [ Period.new(first: nil, last: EARLIEST - 1, count: before, images: []), *periods ]
    end

    # One grouped request: a few records with a picture a visitor may see for each period
    def with_images(periods)
      response = Cache.get(@connection, { q: "*:*", wt: "json", fq: THUMBNAIL_FILTERS, fl: Discovery::FIELDS.join(","), sort: "id asc",
                                          group: true, "group.query": periods.map(&:fq), "group.limit": IMAGES * 3, rows: periods.size })
      grouped = response["grouped"] || {}
      periods.map do |period|
        docs = Array(grouped.dig(period.fq, "doclist", "docs")).map { |doc| SolrDocument.new(doc) }
        images = docs.select { |doc| AccessPolicy.view?(doc) && !Sensitivity.sensitive?(doc) }.first(IMAGES).map do |doc|
          Image.new(id: doc.id.to_s, title: Array(doc["title_tsim"]).first.to_s.strip.presence || "Untitled record", src: doc["thumbnail_path_ssi"].to_s)
        end
        period.with(images: images)
      end
    rescue RSolr::Error::Http => e
      Rails.logger.warn("Explore timeline pictures unavailable: #{e.class}")
      periods
    end
  end
end
