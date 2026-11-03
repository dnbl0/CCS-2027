# frozen_string_literal: true

require "zlib"

# The curated picks (config/featured.yml) and the "Pick of the day" for the home page and /discover (docs/similar-and-trending.md).
#
# Pick of the day. One record a day, the same for every visitor and every process: the day's date is hashed (CRC32, which does not
# vary between processes the way String#hash does) to choose a position among the records with a digital asset anyone may
# download (Discovery.pickable?: the :open tier, not sensitive). If the chosen record is not pickable after all (a record with
# several licences) the next one is tried, up to ATTEMPTS. Records are ordered by id so the position means the same thing all day.
# Idea from Google Arts & Culture's featured item of the day; the code is the app's own.
class FeaturedRecords
  Entry = Data.define(:document, :blurb)

  CONFIG_PATH = Rails.root.join("config/featured.yml")
  # Records with an image a visitor may download: the licence says public domain, and the record has a thumbnail
  POOL_FILTERS = [ 'has_digital_asset_bsi:true', 'licence_type_ssim:"Public domain - Copyright expired"', "-restrictions_tsi:sensitive" ].freeze
  ATTEMPTS = 5

  class << self
    # [{ "id" => ..., "blurb" => ... }, ...] as written in config/featured.yml
    def configured = (YAML.safe_load_file(CONFIG_PATH, aliases: false) || {}).fetch("featured", [])

    # The curated picks that the index has and the sections may list, in the configured order, up to `limit`. [] if Solr cannot answer.
    def picks(limit: 12)
      entries = configured.first(limit * 2)
      blurbs = entries.to_h { |entry| [ entry["id"].to_s, entry["blurb"].presence ] }
      Discovery.fetch(blurbs.keys).select { |document| Discovery.listable?(document) }.first(limit)
        .map { |document| Entry.new(document: document, blurb: blurbs[document.id.to_s]) }
    rescue StandardError => error
      Discovery.log_failure("Featured records", error)
      []
    end

    # The record to pick on `date`, or nil
    def pick_of_the_day(date = Date.current)
      total = pool_size
      return if total.zero?

      start = Zlib.crc32("pick-of-the-day-#{date.iso8601}") % total
      candidates(start, [ ATTEMPTS, total ].min).find { |document| Discovery.pickable?(document) }
    rescue StandardError => error
      Discovery.log_failure("Pick of the day", error)
      nil
    end

    private

    def pool_size
      Discovery.search(q: "*:*", fq: POOL_FILTERS, rows: 0).total
    end

    # `count` records from position `start`, wrapping round to the first if the end of the pool is reached
    def candidates(start, count)
      found = Discovery.search(q: "*:*", fq: POOL_FILTERS, sort: "id asc", start: start, rows: count).documents.to_a
      found += Discovery.search(q: "*:*", fq: POOL_FILTERS, sort: "id asc", start: 0, rows: count - found.size).documents.to_a if found.size < count
      found
    end
  end
end
