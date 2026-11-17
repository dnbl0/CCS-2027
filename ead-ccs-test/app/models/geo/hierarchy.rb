# frozen_string_literal: true

module Geo
  # The Place filter's branches (place_hierarchy_ssim): Region > Country > State > Place, each level a path of the levels above it
  # joined by "|" ("Oceania", "Oceania|Australia", "Oceania|Australia|Victoria"), so a record is found from any level.
  module Hierarchy
    SEPARATOR = "|"
    CONTINENTS = YAML.load_file(Rails.root.join("config/geo/continents.yml")).each_with_object({}) do |(region, codes), map|
      codes.split.each { |code| map[code] = region }
    end.freeze

    # [region, country, state, place] as far down as the geocode goes; nil levels left out, a level that repeats the one above dropped
    def self.segments(geocode)
      return [] unless geocode.located?

      region = geocode.region.presence || CONTINENTS[geocode.country_code.to_s.upcase]
      levels = case geocode.kind
               when "region" then [ region || PlaceName.clean(geocode.place) ]
               when "country" then [ region, geocode.country ]
               when "state" then [ region, geocode.country, geocode.state ]
               else [ region, geocode.country, geocode.state, geocode.locality.presence || PlaceName.clean(geocode.place).split(",").first ]
               end
      levels.map { |level| level.to_s.tr(SEPARATOR, "/").squish }.compact_blank.chunk_while { |a, b| a.casecmp?(b) }.map(&:first)
    end

    # Every path of a branch: ["Oceania", "Oceania|Australia", ...]
    def self.paths(segments) = segments.each_index.map { |index| segments[0..index].join(SEPARATOR) }

    def self.label(path) = path.to_s.split(SEPARATOR).last.to_s

    def self.depth(path) = path.to_s.count(SEPARATOR) + 1

    def self.parent(path) = path.to_s.include?(SEPARATOR) ? path.to_s.rpartition(SEPARATOR).first : nil
  end
end
