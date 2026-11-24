# frozen_string_literal: true

# Explore by time and by place (docs/time-and-place.md; approved as new page types by the product owner, docs/decisions-2027.md #13).
# Lists of periods, eras, regions, countries and places, each opening the search (/catalog) with its filter: no search of their own.
class ExploreController < ApplicationController
  layout "pages"

  # Every century, as the strip; with ?century=, that century's records as a wall of pictures and its decades as tiles
  def time
    @centuries = Explore::Timeline.call
    return render status: :service_unavailable unless @centuries

    @century = Explore::Timeline.century_param(params[:century])
    @century = nil unless @centuries.periods.any? { |period| period.first == @century }
    return unless @century

    @timeline = Explore::Timeline.call(century: @century)
    @records = PictureWall.for("time/#{@century}", "#{Explore::Timeline::FIELD}:[#{@century} TO #{@century + 99}]")
  end

  def places
    @places = Explore::Places.call
    return render status: :service_unavailable unless @places

    @cards = Explore::PlaceCards.for(@places)
  end
end
