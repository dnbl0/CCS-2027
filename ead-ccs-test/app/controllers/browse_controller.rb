# frozen_string_literal: true

# The pages behind the home page's Explore tiles: /browse lists the ways in, and every page under it lists every value of one (BrowseHubs)
# on the one template (browse/_template, browse/hub): object types, classifications, materials, collections, named collections, places,
# time, makers, subjects and colours. Time's, places' and colours' third view (their explorer) is ExploreController's and ColoursController's.
class BrowseController < ApplicationController
  layout "pages"

  # One Browse (docs/ia-audit-handover.md): Browse by category merged in; the sections are CategoriesHelper::BROWSE_SECTIONS. Makers and
  # subjects are the hubs' own cards; the rest are the categories' values
  def index
    @hub_cards = BrowseHubs.all.select { |hub| %w[makers subjects].include?(hub.slug) }.to_h { |hub| [ hub.slug, [ hub, Browse::Cards.for(hub) ] ] }
    @browse_meta = Browse::Meta.index
  end

  def show
    @hub = BrowseHubs.find(params[:slug]) || raise(ActionController::RoutingError, "Not Found")
    @browse_meta = Browse::Meta.hub(@hub)
    @list = BrowseList.new(@hub, letter: params[:letter], filter: params[:filter], page: params[:page], region: params[:region])
    return render("browse/unavailable", status: :service_unavailable) unless @list.available?

    # Every Browse page, after Google Arts & Culture's Places: "All", a mosaic of the values with pictures, or "A–Z" (periods: in order),
    # the whole list by letter
    @hub_view = params[:view] == "az" || @list.letter || @list.filter ? :az : :all
    @wall = @hub_view == :all ? Browse::Cards.wall(@hub) : []
    @wall = @wall.select { |card| PlaceRegions.region_of(card.label) == @list.region } if @list.region
    render "browse/hub"
  end
end
