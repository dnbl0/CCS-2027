# frozen_string_literal: true

# GET /catalog/:id/similar: the "Similar records" section of the record page, loaded into a lazy Turbo frame so the record page
# itself makes the one Solr request it always did (SimilarRecords, docs/similar-and-trending.md). It answers with the frame, or
# with 204 No Content (the section stays hidden) when the record may not have recommendations, there are fewer than two, or
# Solr fails. An id that is not in the index is a 404.
#
# ?row=creator|period|place|type answers one of the labelled rows under it instead (SimilarRows): the same frame mechanism, one
# more Solr request per row, 204 when the row is empty. An unknown row is a 404. A row is drawn as a panel of the record page's
# "More from the collections" tabs (MoreFromCollectionsComponent): three cards and See all, no heading.
class SimilarController < CatalogController
  include DiscoveryFragment

  layout false

  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  def show
    fragment_not_for_indexing
    id = params[:id].to_s
    row = params[:row].presence&.to_s
    raise ActionController::RoutingError, "Not Found" if row && !SimilarRows::KEYS.include?(row)

    document = id.length <= 200 ? Discovery.fetch([ id ], fields: row ? SimilarRows::SOURCE_FIELDS : Discovery::FIELDS).first : nil
    return record_not_found! unless document
    return show_row(document, row) if row
    return show_collage(document) if params[:view] == "collage"

    @documents = SimilarRecords.for(document, exclude: excluded_ids)
    return head(:no_content) if @documents.empty?

    wrap_documents(@documents)
    @entries = @documents.map { |found| FeaturedRecords::Entry.new(document: found, blurb: nil) }
  end

  # Blacklight uses #search_action_url for the header's search box
  def search_action_url(*)
    search_catalog_url(*)
  end

  # The record page's "You may also like" (?view=collage): up to COLLAGE similar records with a picture the visitor may see, six shown
  # at a time and Shuffle for others (similar/collage)
  COLLAGE = 12

  private

  def show_collage(document)
    found = SimilarRecords.for(document, shown: COLLAGE, exclude: excluded_ids)
    @prints = found.filter_map do |record|
      url = AssetVersion.url(record["thumbnail_path_ssi"].presence) if AccessPolicy.view?(record) && !Sensitivity.sensitive?(record)
      [ record, url, Array(record["title_tsim"]).first.presence || record.id ] if url.present?
    end
    return head(:no_content) if @prints.size < 2

    render "similar/collage"
  end

  def show_row(document, key)
    @documents = SimilarRows.for(document, key, exclude: excluded_ids)
    return head(:no_content) if @documents.empty?

    @row = SimilarRows.new(document, key)
    wrap_documents(@documents)
    @entries = @documents.map { |found| FeaturedRecords::Entry.new(document: found, blurb: nil) }
    render "similar/tab"
  end

  # The records the record page already lists as Related objects (?exclude=a,b), so none appears twice
  def excluded_ids
    params[:exclude].to_s.split(",").map(&:strip).select { |value| value.present? && value.length <= 200 }.first(12)
  end
end
