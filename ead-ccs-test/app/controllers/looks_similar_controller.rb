# frozen_string_literal: true

# GET /catalog/:id/looks-similar: the "Looks similar" panel of the record page's More from the collections tabs, in a lazy Turbo frame (LooksSimilar,
# docs/colour-and-clean-up.md). 204 No Content (the section stays hidden) when there is nothing to list or Solr or the database fails;
# 404 for an id not in the index.
class LooksSimilarController < CatalogController
  include DiscoveryFragment

  layout false

  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  rescue_from ActiveRecord::ActiveRecordError, with: :nothing_to_show

  def show
    fragment_not_for_indexing
    id = params[:id].to_s
    document = id.length <= 200 ? Discovery.fetch([ id ]).first : nil
    return record_not_found! unless document

    @documents = LooksSimilar.eligible?(document) ? LooksSimilar.for(document) : []
    return head(:no_content) if @documents.empty?

    wrap_documents(@documents)
  end

  # Blacklight uses #search_action_url for the header's search box
  def search_action_url(*)
    search_catalog_url(*)
  end
end
