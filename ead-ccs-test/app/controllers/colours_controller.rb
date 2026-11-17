# frozen_string_literal: true

# GET /explore/colours: browse the records by the colours of their images (approved by the owner on 2026-11-17, docs/decisions-2027.md).
# One Solr request: the Colour filter's values and counts (colour_ssim, rake colour:write). Each colour opens the results filtered by it.
class ColoursController < ApplicationController
  layout "pages"

  def index
    @colours = ColourCounts.fetch
    render status: :service_unavailable if @colours.nil?
  end
end
