# frozen_string_literal: true

# The page of one collection or named collection (/browse/collections/:slug, /browse/named-collections/:slug): a placeholder introduction
# (config/collection_intros.yml), highlights with pictures, the commonest object types and eras, and the link to every record in the search
# page. The value is found from the category list (Categories.value_for_slug), so an address that names no value is a 404.
class CollectionLandingsController < ApplicationController
  include DiscoveryPage

  INTROS = Rails.root.join("config/collection_intros.yml")

  def show
    @dimension = Categories.find(params[:kind]) || not_found!
    return unavailable! if Categories.values(@dimension).nil?

    @value = Categories.value_for_slug(@dimension, params[:slug]) || not_found!
    canonical = Browse::Slug.build(@dimension.slug, @value)
    return redirect_to(collection_landing_path(kind: @dimension.slug, slug: canonical), status: :moved_permanently) unless params[:slug] == canonical

    @showcase = Showcase.call(fq: [ SolrQuery.field(@dimension.field, @value) ]) || (return unavailable!)
    @search_query = BrowseHubs.query(@dimension.field, @value)
    @intro = self.class.intro(@dimension, @value)
    use_meta @value, @intro, [ [ t("browse.title"), browse_path ], [ @dimension.title, category_path(@dimension.slug) ], [ @value, nil ] ],
             thin: @showcase.total < Browse::MIN_INDEXED_RECORDS
  end

  def self.intro(dimension, value)
    texts = YAML.safe_load_file(INTROS)
    texts.dig(dimension.slug.tr("-", "_"), value).presence || texts.fetch("default")
  end
end
