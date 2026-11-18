# frozen_string_literal: true

# The category, collection, theme and story pages that go in the sitemap (Sitemap, with Browse::SitemapPaths): every category page,
# every theme and story, and each collection or named collection page with at least Browse::MIN_INDEXED_RECORDS records (a thinner one
# asks not to be indexed). The values come from the category cache (Categories.values), so no extra Solr walk.
module DiscoverySitemap
  def self.paths
    routes = Rails.application.routes.url_helpers
    landings = Categories.all.select(&:landing?).flat_map do |dimension|
      Categories.values(dimension).to_a.select { |row| row["count"].to_i >= Browse::MIN_INDEXED_RECORDS }
                .map { |row| routes.collection_landing_path(kind: dimension.slug, slug: Browse::Slug.build(dimension.slug, row["value"])) }
    end
    [ routes.categories_path, *Categories.all.map(&:path), routes.themes_path, *Themes.all.map(&:path), routes.stories_path,
      *Stories.all.map(&:path), *landings.sort ]
  end
end
