module ApplicationHelper
  # The results page filtered to one collection, by the collection's slug (config/pages.yml). The collection landing pages are
  # gone: every link to a collection goes here.
  # Browsing a collection opens all of it: the any_assets marker keeps the default "With a digital asset" filter off
  # (docs/adr/0004), so a collection with few or no images does not open nearly empty
  def collection_results_path(slug)
    search_action_path(NexusCcs::SiteNavigation.whole_collection_query(slug))
  end
end
