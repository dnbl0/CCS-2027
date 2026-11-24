# frozen_string_literal: true

# GET /explore/colours: browse the records by the colours of their images (approved by the owner on 2026-11-17, docs/decisions-2027.md).
# On the Explore template (explore/time's): the colours' share of the collections as a band, then each colour as a picture tile in the
# site's mosaic, in the palette's order (a spectrum). One Solr request for the Colour filter's values and counts (colour_ssim, rake
# colour:write), one grouped request for a picture of each colour (Browse::FacetPictures#prepare, kept for a day; no picture twice).
# Each colour opens the results filtered by it.
class ColoursController < ApplicationController
  layout "pages"

  def index
    @colours = ColourCounts.fetch
    return render status: :service_unavailable if @colours.nil?

    field = CatalogConfig::Facets::COLOUR_FIELD
    @pictures = Browse::FacetPictures.new([]).prepare(@colours.map { |colour| [ field, [ colour.name ] ] })
  end
end
