# frozen_string_literal: true

# The record page's "Looks similar": up to MAX records whose images have the closest colours (colour_neighbours, rake colour:neighbours).
# One database lookup and one Solr request. Only records a visitor may see the image of are listed (has_digital_asset_bsi, and the
# discovery sections' rules: nothing withheld or sensitive).
module LooksSimilar
  MAX = 8
  MIN = 2

  # Records may have "Looks similar" at all: one with an image a visitor may see, listable in the discovery sections
  def self.eligible?(document) = document["has_digital_asset_bsi"] == true && Discovery.listable?(document)

  def self.for(document)
    ids = ColourNeighbour.ids_for(document.id) - [ document.id.to_s ]
    return [] if ids.empty?

    found = Discovery.fetch(ids).select { |other| eligible?(other) && other["thumbnail_path_ssi"].present? }.first(MAX)
    found.size >= MIN ? found : []
  end
end
