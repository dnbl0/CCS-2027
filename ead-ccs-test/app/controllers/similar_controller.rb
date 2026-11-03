# frozen_string_literal: true

# GET /catalog/:id/similar: the "Similar records" section of the record page, loaded into a lazy Turbo frame so the record page
# itself makes the one Solr request it always did (SimilarRecords, docs/similar-and-trending.md). It answers with the frame, or
# with 204 No Content (the section stays hidden) when the record may not have recommendations, there are fewer than two, or
# Solr fails. An id that is not in the index is a 404.
class SimilarController < CatalogController
  include DiscoveryFragment

  layout false

  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  def show
    fragment_not_for_indexing
    id = params[:id].to_s
    document = id.length <= 200 ? Discovery.fetch([ id ]).first : nil
    raise ActionController::RoutingError, "Not Found" unless document

    @documents = SimilarRecords.for(document)
    return head(:no_content) if @documents.empty?

    wrap_documents(@documents)
    @entries = @documents.map { |found| FeaturedRecords::Entry.new(document: found, blurb: nil) }
  end

  # Blacklight uses #search_action_url for the header's search box
  def search_action_url(*)
    search_catalog_url(*)
  end
end
