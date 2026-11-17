# frozen_string_literal: true

module Explore
  # The "explore by place" page (/explore/places, docs/time-and-place.md): one facet request for the map's markers (place_geo_ssim,
  # written by rake geo:write), the Place hierarchy's regions and countries (place_hierarchy_ssim) and, for an index with no
  # coordinates yet, the regions (region_ssim) and the commonest production places. Every entry opens /catalog with a filter.
  class Places
    GEO_FIELD = "place_geo_ssim"
    HIERARCHY_FIELD = "place_hierarchy_ssim"
    REGION_FIELD = "region_ssim"
    PLACE_FIELD = "production_place_ssim"
    TOP_PLACES = 60

    Marker = Data.define(:path, :lat, :lon, :count) do
      def label = Geo::Hierarchy.label(path)
      def country_path = path.split(Geo::Hierarchy::SEPARATOR).first(2).join(Geo::Hierarchy::SEPARATOR)
      def search_query = Places.hierarchy_query(path)
    end

    # A region or country of the hierarchy, with its children (countries, or the places on the map)
    Node = Data.define(:path, :count, :children) do
      def label = Geo::Hierarchy.label(path)
      def search_query = Places.hierarchy_query(path)
    end

    # A plain facet value (the lists shown before any place is located)
    Entry = Data.define(:field, :value, :count) do
      def label = value
      def search_query = { any_assets: "1", search_field: "all_fields", f: { field => [ value ] } }
    end

    Result = Data.define(:markers, :regions, :plain_regions, :top_places) do
      def map? = markers.any?
    end

    def self.hierarchy_query(path) = { any_assets: "1", search_field: "all_fields", f: { HIERARCHY_FIELD => [ path ] } }

    def self.call(connection: nil) = Cache.fetch("places", expires_in: 1.hour) { build(connection) }

    def self.build(connection)
      response = Cache.get(connection, { q: "*:*", rows: 0, wt: "json", facet: true, "facet.mincount": 1, "facet.sort": "count",
                                         "facet.field": [ GEO_FIELD, HIERARCHY_FIELD, REGION_FIELD, PLACE_FIELD ],
                                         "f.#{GEO_FIELD}.facet.limit": -1, "f.#{HIERARCHY_FIELD}.facet.limit": -1,
                                         "f.#{REGION_FIELD}.facet.limit": -1, "f.#{PLACE_FIELD}.facet.limit": TOP_PLACES * 2 })
      markers = markers(Browse::Facets.pairs(response, GEO_FIELD))
      Result.new(markers: markers, regions: tree(Browse::Facets.pairs(response, HIERARCHY_FIELD), markers),
                 plain_regions: entries(response, REGION_FIELD), top_places: entries(response, PLACE_FIELD).first(TOP_PLACES))
    end

    # "lat,lon|Oceania|Australia|Victoria|Melbourne" => markers, one a place (two spellings at one place are added together)
    def self.markers(pairs)
      pairs.filter_map do |value, count|
        point, path = value.to_s.split(Geo::Hierarchy::SEPARATOR, 2)
        lat, lon = point.to_s.split(",").map { |number| Float(number, exception: false) }
        [ path, lat, lon, count ] if path.present? && lat && lon
      end.group_by(&:first).map do |path, rows|
        Marker.new(path: path, lat: rows.first[1], lon: rows.first[2], count: rows.sum(&:last))
      end.sort_by { |marker| [ -marker.count, marker.path ] }
    end

    # Regions (depth 1) with their countries (depth 2), each country with its places on the map, most records first
    def self.tree(pairs, markers)
      counts = pairs.to_h
      by_country = markers.group_by(&:country_path)
      regions = counts.keys.select { |path| Geo::Hierarchy.depth(path) == 1 }
      regions.map do |region|
        countries = counts.keys.select { |path| Geo::Hierarchy.parent(path) == region }.map do |country|
          Node.new(path: country, count: counts[country], children: Array(by_country[country]).reject { |marker| marker.path == country })
        end
        Node.new(path: region, count: counts[region], children: countries.sort_by { |node| [ -node.count, node.label ] })
      end.sort_by { |node| [ -node.count, node.label ] }
    end

    def self.entries(response, field)
      Browse::Facets.pairs(response, field).reject { |value, _| Browse.noise?(value) }.map { |value, count| Entry.new(field, value, count) }
    end

    private_class_method :build, :markers, :tree, :entries
  end
end
