# frozen_string_literal: true

# The pages behind the home page's Explore tiles: /browse lists the ways in, /browse/:slug lists every value of one (BrowseHubs).
class BrowseController < ApplicationController
  layout "pages"

  def index
    @sections = BrowseHubs.all.to_h { |hub| [ hub, Browse::Cards.for(hub) ] }
    @browse_meta = Browse::Meta.index
  end

  def show
    @hub = BrowseHubs.find(params[:slug]) || raise(ActionController::RoutingError, "Not Found")
    @browse_meta = Browse::Meta.hub(@hub)
    @list = BrowseList.new(@hub, letter: params[:letter], filter: params[:filter], page: params[:page])
    return render(status: :service_unavailable) unless @list.available?

    # Places (after Google Arts & Culture's Places): "All", a wall of the places with pictures, or "A–Z", the whole list by letter
    return unless @hub.slug == "places"

    @places_view = params[:view] == "az" || @list.letter || @list.filter ? :az : :all
    @wall = @places_view == :all ? Browse::Cards.wall(@hub) : []
    render "browse/places"
  end
end
