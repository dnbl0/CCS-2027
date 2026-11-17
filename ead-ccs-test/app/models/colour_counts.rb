# frozen_string_literal: true

# The colour browse page's colours (ColoursController): each colour name in Colour::Palette::NAMES order with how many records with a
# viewable image have it. [] when the index has no colours yet; nil when Solr cannot be asked.
module ColourCounts
  Entry = Data.define(:name, :count)

  def self.fetch
    response = Blacklight.default_index.search(params: {
      q: "*:*", fq: "has_digital_asset_bsi:true", rows: 0, facet: true, "facet.field": CatalogConfig::Facets::COLOUR_FIELD,
      "facet.limit": -1, "facet.mincount": 1, wt: "json"
    })
    counts = Array(response.dig("facet_counts", "facet_fields", CatalogConfig::Facets::COLOUR_FIELD)).each_slice(2).to_h
    Colour::Palette::NAMES.filter_map { |name| Entry.new(name: name, count: counts[name].to_i) if counts[name].to_i.positive? }
  rescue StandardError => e
    Rails.logger.warn("Colour counts unavailable: #{e.class}")
    nil
  end
end
