# frozen_string_literal: true

# A shared list, read-only, at /galleries/:token: the title, the description and the records as the site's result cards, in the
# order the owner's list shows them. Anyone with the link can open it; it is not listed anywhere, is noindex and nofollow
# (RobotsPolicy lists /galleries) and says nothing about who made it. A malformed, unknown or revoked token is a 404.
#
# The records are fetched from Solr once, in one batch. What the viewer sees of each is decided as on the results pages (the
# card: AccessPolicy and Sensitivity), so a withheld or sensitive record has no image; records no longer in the index drop out
# with a note. "Add to my list" copies the gallery to the viewer's own lists. It is a CatalogController, as ListsController
# is, so that the records are drawn by the same view. Behind config.x.saved_records with the lists it is made from (routes).
class GalleriesController < CatalogController
  include GuestLists
  include CitationsPage

  layout "pages"

  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  skip_before_action :apply_search_defaults, raise: false
  before_action :find_gallery
  # The token is in this page's address: it must not travel to other sites in a Referer header (same-origin keeps the
  # "Save" and "Add to list" buttons' redirect back to this page working)
  before_action { response.headers["Referrer-Policy"] = "same-origin" }

  def show
    @items = @list.list_items.recent.to_a
    @documents = @items.empty? ? [] : documents_in_order(@items.map(&:document_id))
    @missing = @items.size - @documents.size
    @without_image = @documents.count { |document| SharedMedia.withheld_reason(document) }
    # the chosen cover when its image may be shown, else the first record whose image may be
    @cover = @documents.find { |document| document.id.to_s == @list.cover_document_id.to_s && SharedMedia.thumbnail_path(document) }
    @cover ||= @documents.find { |document| SharedMedia.thumbnail_path(document) }
    @cover_path = @cover && SharedMedia.thumbnail_path(@cover)
  end

  def citations
    ids = @list.list_items.recent.pluck(:document_id)
    render_citations(ids.empty? ? [] : documents_in_order(ids), heading: @list.name, back_path: gallery_path(@list.share_token),
                                                                  back_label: t("nexus_ccs.galleries.back_to_gallery", name: @list.name))
  end

  # "Add to my list": a copy in the viewer's own lists (their guest is made now, if they have none)
  def copy
    copy = @list.copy_for(guest_owner)
    if copy.persisted?
      redirect_to list_path(copy), notice: t("nexus_ccs.galleries.copied", name: copy.name)
    else
      redirect_to gallery_path(@list.share_token), alert: t("nexus_ccs.galleries.copy_failed", reason: copy.errors.full_messages.to_sentence)
    end
  end

  # Blacklight uses #search_action_url for the header's search box
  def search_action_url(*)
    search_catalog_url(*)
  end

  private

  def find_gallery
    @list = List.find_shared(params[:token])
    raise ActionController::RoutingError, "Not Found" unless @list
  end

  # As ListsController: wrapped as a response, as Blacklight's helpers (the Save control) read the page's documents from it
  def documents_in_order(ids)
    by_id = search_service.fetch(ids).index_by { |document| document.id.to_s }
    docs = ids.filter_map { |id| by_id[id.to_s]&._source }
    @response = Blacklight::Solr::Response.new({ "response" => { "docs" => docs, "numFound" => docs.size, "start" => 0 } }, {},
                                               blacklight_config: blacklight_config)
    @response.documents
  end
end
