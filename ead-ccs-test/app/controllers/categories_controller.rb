# frozen_string_literal: true

# A category's own page (Categories): /browse/collections, /browse/named-collections, /browse/classifications and /browse/materials show a
# card for every value (the other categories open their own pages; the list of every way in is /browse, BrowseController), sorted by record count or A to Z, 48 a page. Each card opens the search page with that value as a filter.
class CategoriesController < ApplicationController
  include DiscoveryPage

  def show
    @dimension = Categories.find(params[:slug])
    not_found! unless @dimension&.own_page?
    @page = Categories.page(@dimension, sort: params[:sort], page: params[:page])
    use_meta @dimension.title, @dimension.intro,
             [ [ t("browse.title"), browse_path ], [ @dimension.title, nil ] ], keep: %w[page]
    unavailable! unless @page
  end
end
