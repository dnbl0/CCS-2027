# frozen_string_literal: true

module Geo
  # rake geo:write (docs/time-and-place.md): writes where each record was made into the DAM index (DAM_SOLR_URL), as Solr atomic
  # updates, for the records whose place fields changed only (a digest, geo_digest_ssi, says whether they did). Like
  # Dam::SolrWriter it never writes to the shared core: an atomic update rewrites the whole document.
  #
  #   place_latlon_llsim    "lat,lon" of each located place (the schema's `location` type, so spatial queries work)
  #   place_geo_ssim        "lat,lon|Oceania|Australia|Victoria|Melbourne": the map's markers, one facet request for all of them
  #   place_country_ssim, place_state_ssim
  #   place_hierarchy_ssim  "Oceania", "Oceania|Australia", ...: the Place filter (NexusCcs::PlaceHierarchyFacetComponent)
  class SolrWriter
    PLACE_FIELD = "production_place_ssim"
    FIELDS = %w[place_latlon_llsim place_geo_ssim place_country_ssim place_state_ssim place_hierarchy_ssim geo_digest_ssi].freeze
    BATCH = 500

    def self.from_env
      url = ENV["DAM_SOLR_URL"].presence
      raise Error, "DAM_SOLR_URL is not set: geo:write writes only to the DAM sync's own core (docs/time-and-place.md)" unless url

      new(solr: RSolr.connect(url: url))
    end

    def initialize(solr:, logger: Rails.logger)
      @solr = solr
      @logger = logger
    end

    # Returns how many records were updated
    def write(geocodes = PlaceGeocode.found.to_a)
      by_place = geocodes.select(&:located?).index_by(&:place)
      updated = 0
      cursor = "*"
      loop do
        response = @solr.get("select", params: { q: "#{PLACE_FIELD}:* OR geo_digest_ssi:*", fl: "id,#{PLACE_FIELD},geo_digest_ssi",
                                                 sort: "id asc", rows: BATCH, cursorMark: cursor, wt: "json" })
        updates = Array(response.dig("response", "docs")).filter_map { |doc| update_for(doc, by_place) }
        if updates.any?
          @solr.add(updates)
          updated += updates.size
        end
        break if response["nextCursorMark"].blank? || response["nextCursorMark"] == cursor

        cursor = response["nextCursorMark"]
      end
      @solr.commit if updated.positive?
      @logger.info("[geo] #{updated} records updated")
      updated
    end

    # The fields of a record with these production places (nil values when none is located)
    def self.fields_for(places, by_place)
      located = Array(places).filter_map { |place| by_place[place] }
      return FIELDS.index_with { nil } if located.empty?

      branches = located.map { |geocode| [ geocode, Hierarchy.segments(geocode) ] }.reject { |_geocode, segments| segments.empty? }
      fields = {
        "place_latlon_llsim" => located.reject { |geocode| geocode.kind == "region" }.map { |geocode| point(geocode) }.uniq.presence,
        "place_geo_ssim" => branches.reject { |geocode, _| geocode.kind == "region" }
                                    .map { |geocode, segments| "#{point(geocode)}|#{segments.join(Hierarchy::SEPARATOR)}" }.uniq.presence,
        "place_country_ssim" => located.filter_map(&:country).uniq.presence,
        "place_state_ssim" => located.filter_map(&:state).uniq.presence,
        "place_hierarchy_ssim" => branches.flat_map { |_geocode, segments| Hierarchy.paths(segments) }.uniq.presence
      }
      fields.merge("geo_digest_ssi" => Digest::SHA256.hexdigest(fields.to_json))
    end

    def self.point(geocode) = format("%.5f,%.5f", geocode.lat, geocode.lon)

    private

    def update_for(doc, by_place)
      fields = self.class.fields_for(doc[PLACE_FIELD], by_place)
      return nil if fields["geo_digest_ssi"] == doc["geo_digest_ssi"]

      { "id" => doc["id"] }.merge(fields.transform_values { |value| { "set" => value } })
    end
  end
end
