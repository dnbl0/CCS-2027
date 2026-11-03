# frozen_string_literal: true

module Browse
  # Reads a facet or range out of a Solr response, whether Solr sent it as a map ("json.nl": "map") or as the flat list
  module Facets
    def self.pairs(response, field)
      listed = response.dig("facet_counts", "facet_fields", field)
      case listed
      when Hash then listed.map { |value, count| [ value, count.to_i ] }
      when Array then listed.each_slice(2).map { |value, count| [ value, count.to_i ] }
      else []
      end
    end

    # { start year => count } of a facet.range
    def self.range(response, field)
      counts = response.dig("facet_counts", "facet_ranges", field, "counts")
      pairs = counts.is_a?(Hash) ? counts.to_a : Array(counts).each_slice(2).to_a
      pairs.to_h { |start, count| [ start.to_i, count.to_i ] }
    end

    def self.query_count(response, key) = response.dig("facet_counts", "facet_queries", key).to_i

    def self.before(response, field) = response.dig("facet_counts", "facet_ranges", field, "before").to_i
  end
end
