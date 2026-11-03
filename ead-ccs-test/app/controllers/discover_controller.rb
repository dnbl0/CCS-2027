# frozen_string_literal: true

# /discover: the Pick of the day, the Featured records and the Trending records in full (docs/similar-and-trending.md). A public
# page: indexed, in the sitemap, and the page the home page's "Featured and trending" section links to (that section loads
# DiscoverController#frame, a shorter version, into a lazy Turbo frame, so the home page's own HTML stays small and asks Solr for
# nothing). It is a CatalogController so that the result cards draw as they do on a results page.
class DiscoverController < CatalogController
  include DiscoveryFragment

  FULL = 12
  HOME = 4

  layout "pages"

  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  def index
    @sections = DiscoverSections.build(limit: FULL)
    wrap_documents(@sections.flat_map { |section| section.entries.map(&:document) })
  end

  # The home page's frame: fewer records. Nothing to show is still an answer (the frame says so), unlike Similar records.
  def frame
    fragment_not_for_indexing
    @sections = DiscoverSections.build(limit: HOME)
    wrap_documents(@sections.flat_map { |section| section.entries.map(&:document) })
    render layout: false
  end

  # Blacklight uses #search_action_url for the header's search box
  def search_action_url(*)
    search_catalog_url(*)
  end
end
