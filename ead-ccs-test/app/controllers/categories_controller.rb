# frozen_string_literal: true

# The category picture pages (Categories): /browse/categories lists the ways of grouping, /browse/categories/:slug shows a card for every
# value, sorted by record count or A to Z, 48 a page. Each card opens the search page with that value as a filter.
class CategoriesController < ApplicationController
  include DiscoveryPage

  def index
    use_meta t("nexus_ccs.categories.title"), t("nexus_ccs.categories.description"), [ [ t("browse.title"), browse_path ], [ t("nexus_ccs.categories.title"), nil ] ]
  end

  def show
    @dimension = Categories.find(params[:slug]) || not_found!
    @page = Categories.page(@dimension, sort: params[:sort], page: params[:page])
    use_meta @dimension.title, @dimension.intro,
             [ [ t("browse.title"), browse_path ], [ t("nexus_ccs.categories.title"), categories_path ], [ @dimension.title, nil ] ], keep: %w[page]
    unavailable! unless @page
  end
end
