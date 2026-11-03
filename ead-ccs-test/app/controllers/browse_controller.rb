# frozen_string_literal: true

# The pages behind the home page's Explore tiles: /browse lists the ways in, /browse/:slug lists every value of one (BrowseHubs).
class BrowseController < ApplicationController
  layout "pages"

  def index
    @hubs = BrowseHubs.all
  end

  def show
    @hub = BrowseHubs.find(params[:slug]) || raise(ActionController::RoutingError, "Not Found")
    @list = BrowseList.new(@hub, letter: params[:letter])
    render status: :service_unavailable unless @list.available?
  end
end
