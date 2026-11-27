# frozen_string_literal: true

# Off unless FILM_ALL_COLLECTIONS is set (made for the 2027 showcase film): the Collection Title facet lists every
# University collection, as the home page's tiles do (ExploreEntryPoints::FILM_COLLECTIONS). A collection with no records in this index
# has no count beside it (none is invented). The list is the facet's own: the sidebar shows its first values and Blacklight's
# "More Collection Title" link opens the rest in its facet modal; Advanced search lists them all as checkboxes.
if ENV["FILM_ALL_COLLECTIONS"].present?
  module FilmAllCollections
    FIELD = "collection_ssim"

    def aggregations
      return super if @film_all_collections_done

      @film_all_collections_done = true
      super.tap do |aggs|
        facet = aggs[FIELD]
        next unless facet

        # no record counts beside collections (they may not be exact), and "University of Melbourne" (3 stray records) is not a collection
        facet.items.reject! { |item| item.value == "University of Melbourne" }
        facet.items.each { |item| item.hits = nil }
        present = facet.items.map(&:value)
        missing = facet.offset.to_i.positive? ? [] : ExploreEntryPoints::FILM_COLLECTIONS.map(&:first) - present
        extra = missing.sort_by(&:downcase).map { |value| Blacklight::Solr::Response::Facets::FacetItem.new(value: value, hits: nil) }
        items = facet.items + extra
        items = items.sort_by { |item| item.value.to_s.downcase } if facet.index?
        facet.instance_variable_set(:@items, items)
      end
    end
  end

  Rails.application.config.to_prepare do
    Blacklight::Solr::Response.prepend(FilmAllCollections) unless Blacklight::Solr::Response.ancestors.include?(FilmAllCollections)
  end
end
