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
    @list = BrowseList.new(@hub, letter: params[:letter], filter: params[:filter], page: params[:page], region: params[:region])
    return render(status: :service_unavailable) unless @list.available?

    # Every Browse page, after Google Arts & Culture's Places: "All", a mosaic of the values with pictures, or "A–Z" (periods: in order),
    # the whole list by letter
    @hub_view = params[:view] == "az" || @list.letter || @list.filter ? :az : :all
    @wall = @hub_view == :all ? Browse::Cards.wall(@hub) : []
    @wall = @wall.select { |card| PlaceRegions.region_of(card.label) == @list.region } if @list.region
    render "browse/hub"
  end
end
