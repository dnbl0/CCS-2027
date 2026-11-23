# frozen_string_literal: true

# Explore by time and by place (docs/time-and-place.md; approved as new page types by the product owner, docs/decisions-2027.md #13).
# Lists of periods, eras, regions, countries and places, each opening the search (/catalog) with its filter: no search of their own.
class ExploreController < ApplicationController
  layout "pages"

  def time
    @century = Explore::Timeline.century_param(params[:century])
    @timeline = Explore::Timeline.call(century: @century)
    render status: :service_unavailable unless @timeline
  end

  def places
    @places = Explore::Places.call
    return render status: :service_unavailable unless @places

    @cards = Explore::PlaceCards.for(@places)
  end
end
