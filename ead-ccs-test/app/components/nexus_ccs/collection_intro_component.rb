# frozen_string_literal: true

module NexusCcs
  # Above the results filtered to one collection (the Browse records menu, the home page's cards): the collection's name,
  # a line about it, its named collections and a link to visit it, from config/pages.yml. Nothing for any other search.
  class CollectionIntroComponent < ViewComponent::Base
    NAMED_FIELD = "named_collection_ssim"

    # params: the search parameters (string keys)
    def initialize(params:)
      @params = params
    end

    def render? = collection.present?

    def collection
      return @collection if defined?(@collection)

      values = @params.dig("f", BrowseMenu::COLLECTION_FIELD)
      slug = SiteNavigation.slug_for(values.first) if values.is_a?(Array) && values.size == 1
      @collection = slug && SitePages.collection(slug)
    end

    def named_collections = SitePages.browse.fetch("sub_collections").select { |entry| entry["collection"] == collection["facet_value"] }

    def named_path(entry)
      query = BrowseMenu.query(BrowseMenu::COLLECTION_FIELD, collection["facet_value"])
      helpers.search_action_path(query.merge(f: query[:f].merge(NAMED_FIELD => [ entry["named"] ])))
    end
  end
end
