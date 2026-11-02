# frozen_string_literal: true

# The home page's "Explore by" section: ways into the records that need no search term, by object type, place and time (the
# entry points Google Arts & Culture and Europeana lead with). Every link opens all the matching records: the any_assets
# marker keeps the default "With a digital asset" filter off (docs/adr/0004).
#
# The values and numbers come from one Solr request, kept for a day, and the last good answer for a month, as BrowseMenu does
# (CCS-147). If Solr cannot answer and nothing is kept, there are no groups and the home page leaves the section out.
module ExploreEntryPoints
  Group = Data.define(:id, :heading, :items)
  Item = Data.define(:label, :count, :query)

  OBJECT_TYPE_FIELD = "object_type_ssim"
  PLACE_FIELD = "production_place_ssim"
  DATE_FIELD = "date_start_isi"
  LIMIT = 8
  CACHE_KEY = "explore_entry_points/v1"
  LAST_GOOD_KEY = "explore_entry_points/last_good/v1"
  # BC dates are real (negative years), so the first period has no lower bound worth showing
  EARLIEST_YEAR = -10_000

  # [label, first year, last year]
  def self.periods(this_year = Time.zone.today.year)
    [
      [ "Before 1000", EARLIEST_YEAR, 999 ], [ "1000–1499", 1000, 1499 ], [ "1500–1799", 1500, 1799 ],
      [ "1800–1899", 1800, 1899 ], [ "1900–1999", 1900, 1999 ], [ "2000 onwards", 2000, this_year ]
    ]
  end

  def self.period_key(first, last) = "#{first}-#{last}"

  # counts: as ExploreEntryPoints.counts returns them (empty when Solr is unavailable)
  def self.groups(counts = self.counts)
    return [] if counts.blank?

    [
      facet_group("object-type", "Object type", OBJECT_TYPE_FIELD, counts[OBJECT_TYPE_FIELD]),
      facet_group("place", "Place", PLACE_FIELD, counts[PLACE_FIELD]),
      period_group(counts["periods"] || {})
    ].select { |group| group.items.any? }
  end

  def self.counts(connection = nil)
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.day, skip_nil: true) do
      fetched = fetch_counts(connection || Blacklight.default_index.connection)
      Rails.cache.write(LAST_GOOD_KEY, fetched, expires_in: 30.days) if fetched
      fetched
    end || Rails.cache.read(LAST_GOOD_KEY) || {}
  end

  def self.fetch_counts(connection)
    response = SolrGuard.run do
      connection.get("select", params: {
        q: "*:*", rows: 0, wt: "json", facet: true, "facet.mincount": 1, "facet.limit": LIMIT, "facet.sort": "count",
        "facet.field": [ OBJECT_TYPE_FIELD, PLACE_FIELD ],
        "facet.query": periods.map { |_label, first, last| period_query(first, last) }
      })
    end
    facets = response.dig("facet_counts", "facet_fields") || {}
    queries = response.dig("facet_counts", "facet_queries") || {}
    {
      OBJECT_TYPE_FIELD => facets[OBJECT_TYPE_FIELD].to_a.each_slice(2).to_a,
      PLACE_FIELD => facets[PLACE_FIELD].to_a.each_slice(2).to_a,
      "periods" => periods.to_h { |_label, first, last| [ period_key(first, last), queries[period_query(first, last)] ] }
    }
  rescue RSolr::Error::Http, RSolr::Error::ConnectionRefused, RSolr::Error::Timeout, Faraday::Error, SystemCallError, Timeout::Error => e
    Rails.logger.warn("Explore entry points unavailable: #{e.class}")
    nil
  end

  def self.period_query(first, last) = "#{DATE_FIELD}:[#{first} TO #{last}]"

  def self.facet_group(id, heading, field, pairs)
    items = pairs.to_a.map do |value, count|
      Item.new(value, count, { any_assets: "1", f: { field => [ value ] }, search_field: "all_fields" })
    end
    Group.new(id, heading, items)
  end

  def self.period_group(counts)
    items = periods.filter_map do |label, first, last|
      count = counts[period_key(first, last)].to_i
      next if count.zero?

      Item.new(label, count, { any_assets: "1", range: { DATE_FIELD => { begin: first, end: last } }, search_field: "all_fields" })
    end
    Group.new("time", "Time", items)
  end

  private_class_method :fetch_counts, :period_query, :facet_group, :period_group
end
