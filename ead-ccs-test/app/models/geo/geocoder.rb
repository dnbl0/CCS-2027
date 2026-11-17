# frozen_string_literal: true

module Geo
  # rake geo:geocode (docs/time-and-place.md): reads every distinct production place, with the commonest region of its records, from
  # SOLR_URL (read only), and looks up the places not yet in place_geocodes with Nominatim, one a second. Every answer is kept,
  # "not found" too, so a stopped run resumes where it was and nothing is asked twice; a failed request is reported and asked again
  # next run. dry_run: counts what would be looked up and changes nothing.
  class Geocoder
    PLACE_FIELD = "production_place_ssim"
    REGION_FIELD = "region_ssim"

    Report = Struct.new(:places, :cached, :copied, :looked_up, :found, :not_found, :failures, :dry_run, keyword_init: true) do
      def lines
        verb = dry_run ? "would look up" : "looked up"
        lines = [ "#{places} places: #{cached} already known, #{copied} copied from another spelling, #{looked_up} #{verb} " \
                  "(#{found} found, #{not_found} not found), #{failures.size} failed" ]
        lines + failures.map { |place, error| "  failed: #{place} (#{error})" }
      end
    end

    def initialize(solr:, client: Nominatim.new, logger: Rails.logger, dry_run: false, limit: nil)
      @solr = solr
      @client = client
      @logger = logger
      @dry_run = dry_run
      @limit = limit
    end

    def run
      report = Report.new(places: 0, cached: 0, copied: 0, looked_up: 0, found: 0, not_found: 0, failures: [], dry_run: @dry_run)
      places.each do |place, region|
        report.places += 1
        row = PlaceGeocode.find_or_initialize_by(place: place)
        row.normalised = PlaceName.normalise(place)
        row.region = region if region.present? || row.region.blank?
        if row.looked_up_at
          report.cached += 1
          row.save! if row.changed? && !@dry_run
        elsif (twin = PlaceGeocode.looked_up.where(normalised: row.normalised).where.not(place: place).first)
          report.copied += 1
          copy(twin, row) unless @dry_run
        elsif @limit && report.looked_up >= @limit
          next
        else
          report.looked_up += 1
          next if @dry_run

          look_up(row, report)
        end
      end
      report
    end

    # [[place, commonest region or nil], ...] for every place worth looking up
    def places
      response = @solr.get("select", params: { q: "*:*", rows: 0, wt: "json", facet: true, "facet.pivot": "#{PLACE_FIELD},#{REGION_FIELD}",
                                               "facet.limit": -1, "facet.mincount": 1, "facet.pivot.mincount": 1 })
      Array(response.dig("facet_counts", "facet_pivot", "#{PLACE_FIELD},#{REGION_FIELD}")).filter_map do |entry|
        place = entry["value"].to_s
        next if PlaceName.skip?(place)

        region = Array(entry["pivot"]).max_by { |sub| sub["count"].to_i }&.dig("value")
        [ place, region ]
      end
    end

    private

    def look_up(row, report)
      result = @client.lookup(PlaceName.clean(row.place))
      if result
        report.found += 1
        row.assign_attributes(result.to_h.merge(not_found: false))
      else
        report.not_found += 1
        row.assign_attributes(not_found: true, lat: nil, lon: nil)
      end
      row.update!(source: "nominatim", looked_up_at: Time.current)
      @logger.info("[geo] #{row.place}: #{result ? "#{result.lat},#{result.lon}" : 'not found'}")
    rescue Geo::Error => e
      report.failures << [ row.place, e.message ]
      @logger.warn("[geo] #{row.place}: #{e.message}")
    end

    def copy(twin, row)
      row.assign_attributes(twin.attributes.slice(*%w[lat lon country country_code state locality kind source looked_up_at not_found]))
      row.save!
    end
  end
end
