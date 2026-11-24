# frozen_string_literal: true

# GET /explore/colours: browse the records by the colours of their images (approved by the owner on 2026-11-17, docs/decisions-2027.md),
# after Google Arts & Culture's Color Explorer (looked at 2026-11-24): a strip of the colours, every one the same width, the chosen one
# marked and kept in view; under it, the chosen colour's records as a wall of square pictures (PictureWall), or, before a colour is
# chosen, each colour as a picture tile (Browse::FacetPictures#prepare: one grouped request, no picture twice). ?colour= chooses one;
# a colour the index does not have is no choice. One Solr request for the colours and their counts (colour_ssim, rake colour:write).
class ColoursController < ApplicationController
  layout "pages"

  def index
    @colours = ColourCounts.fetch
    return render status: :service_unavailable if @colours.nil?

    @colour = @colours.find { |colour| colour.name == params[:colour].to_s }
    if @colour
      field = CatalogConfig::Facets::COLOUR_FIELD
      # those whose image has the colour as its biggest share first (colour_ssim is ranked, the biggest first), so the wall reads as it
      @records = PictureWall.for("colour/#{@colour.name}", Browse.field_query(field, [ @colour.name ]), fields: [ field ]) { |document| Array(document[field]).first == @colour.name }
    else
      field = CatalogConfig::Facets::COLOUR_FIELD
      @pictures = Browse::FacetPictures.new([]).prepare(@colours.map { |colour| [ field, [ colour.name ] ] })
    end
  end
end
