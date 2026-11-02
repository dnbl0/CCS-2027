# frozen_string_literal: true

# The records a visitor has ticked on the results pages (CCS-40, Selection): add and remove them, view only them in the order
# they were chosen, cite them. Listing, downloading and the record page's next and previous links are in the views. The
# selection lives in the session cookie (Selection), so every action works without a login, without saved records being on, and
# without JavaScript: the results page's form posts here and comes back with a notice. JavaScript posts the same form and
# asks for JSON, so the page need not reload.
# It is a CatalogController so that the records are fetched and drawn like a list's (ListsController).
class SelectionsController < CatalogController
  include CitationsPage

  PAGE_IDS_LIMIT = 200 # a results page holds 96 at most

  layout "pages"

  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  skip_before_action :apply_search_defaults, raise: false

  def show
    @selection = Selection.new(session)
    asked = @selection.ids
    @documents = documents_in_order(asked)
    @missing = asked.size - @documents.size
    @selection.keep_only(@documents.map { |document| document.id.to_s }) # a record dropped from the index leaves the selection
  end

  # intent=update (the default): within page_ids, exactly ids[] are selected. all: every page_ids record. clear: nothing.
  def create
    selection = Selection.new(session)
    refused = apply(selection, params[:intent].to_s)

    respond_to do |format|
      format.json { render json: { count: selection.count, ids: selection.ids, max: Selection::MAX, full: selection.full?, refused: refused } }
      format.html { redirect_to(return_path, status: :see_other, **message(selection, refused)) }
    end
  end

  # The citations of the selected records, in the order selected
  def citations
    ids = Selection.new(session).ids
    render_citations(ids.empty? ? [] : documents_in_order(ids), heading: t("nexus_ccs.selection.title"), back_path: selection_path,
                                                                  back_label: t("nexus_ccs.selection.back"))
  end

  # Blacklight uses #search_action_url for the header's search box
  def search_action_url(*)
    search_catalog_url(*)
  end

  private

  def page_ids = Array(params[:page_ids]).grep(String).first(PAGE_IDS_LIMIT)

  def apply(selection, intent)
    case intent
    when "clear"
      selection.clear
      []
    when "all" then selection.add(page_ids)
    else selection.sync(scope: page_ids, chosen: Array(params[:ids]).grep(String))
    end
  end

  # Back to the page the form was on (any page of this site), or the selection
  def return_path = url_from(params[:return_to]) || selection_path

  def message(selection, refused)
    if refused.any?
      { alert: t("nexus_ccs.selection.full", count: Selection::MAX) }
    else
      { notice: t("nexus_ccs.selection.status", count: selection.count) }
    end
  end

  # As ListsController: in the order asked for, records no longer in the index left out, wrapped as a response because
  # Blacklight's helpers (the Save control's bookmarks) read the page's documents from @response.
  def documents_in_order(ids)
    return [] if ids.empty?

    by_id = search_service.fetch(ids).index_by { |document| document.id.to_s }
    docs = ids.filter_map { |id| by_id[id.to_s]&._source }
    @response = Blacklight::Solr::Response.new({ "response" => { "docs" => docs, "numFound" => docs.size, "start" => 0 } }, {},
                                               blacklight_config: blacklight_config)
    @response.documents
  end
end
