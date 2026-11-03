# frozen_string_literal: true

# Named lists (CCS-389, CCS-129, CCS-136): a visitor makes lists of their own, renames and deletes them, and opens one to see
# its records as the site's result cards. Adding and removing records is ListItemsController. Visitors have no login: the
# owner is the guest user of the session cookie (GuestLists). Behind config.x.saved_records (routes).
# It is a CatalogController so that a list's records are fetched and drawn like the saved records page's.
class ListsController < CatalogController
  include GuestLists
  include CitationsPage

  layout "pages"

  # Its own copy of the catalog's configuration: a list's records do not belong to a search to step back and forward through
  copy_blacklight_config_from(CatalogController)
  blacklight_config.track_search_session.storage = false

  skip_before_action :apply_search_defaults, raise: false
  before_action :find_list, only: %i[show edit update destroy citations]

  def index
    @lists = visitor_lists.by_name.includes(:list_items).load # loaded once: the view's count and empty check then cost no queries
  end

  def show
    items = @list.list_items.recent.to_a
    @items = items
    @documents = items.empty? ? [] : documents_in_order(items.map(&:document_id))
    @missing = items.size - @documents.size
  rescue *SolrGuard::FAILURES => e
    # Solr is down: the list still opens, with its records named by id until the cards can be drawn (CCS-147)
    Rails.logger.warn("List shown without its records, search unavailable: #{e.class}")
    @documents = []
    @missing = 0
    @unavailable = true
    response.headers["Retry-After"] = ErrorsController::RETRY_AFTER.fetch("503").to_s
  end

  # The citations of the list's records (CCS-137)
  def citations
    ids = @list.list_items.recent.pluck(:document_id)
    render_citations(ids.empty? ? [] : documents_in_order(ids), heading: @list.name, back_path: list_path(@list),
                                                                  back_label: t("nexus_ccs.cite_page.back_to_list", name: @list.name))
  end

  def new
    @list = List.new
  end

  def edit; end

  def create
    owner = guest_owner
    name = params.dig(:list, :name)
    @list = List.just_made(owner, name) || owner.lists.build(name: name) # a repeated request finds the list the first one made
    document_id = params[:document_id].presence

    if @list.persisted? || save_once(@list, owner, name)
      add_once(@list, document_id) if document_id
      notice = t(document_id ? "nexus_ccs.lists.created_with_record" : "nexus_ccs.lists.created", name: @list.name)
      document_id ? back_or_to_lists(notice: notice) : redirect_to(list_path(@list), notice: notice)
    elsif document_id
      back_or_to_lists(alert: t("nexus_ccs.lists.failure", reason: @list.errors.full_messages.to_sentence))
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @list.update(name: params.dig(:list, :name))
      redirect_to list_path(@list), notice: t("nexus_ccs.lists.renamed", name: @list.name)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @list.destroy
    redirect_to lists_path, notice: t("nexus_ccs.lists.deleted", name: @list.name)
  end

  # Blacklight uses #search_action_url for the header's search box
  def search_action_url(*)
    search_catalog_url(*)
  end

  private

  # Saves the new list. The unique index (name, ignoring case) settles two requests at once: the one that lost finds the winner's list.
  def save_once(list, owner, name)
    list.save
  rescue ActiveRecord::RecordNotUnique
    existing = List.just_made(owner, name)
    if existing
      @list = existing
    else
      list.errors.add(:name, :taken)
    end
    existing.present?
  end

  def add_once(list, document_id)
    list.list_items.create(document_id: document_id)
  rescue ActiveRecord::RecordNotUnique
    nil # already in the list
  end

  def find_list
    @list = visitor_lists.find_by(id: params[:id])
    redirect_to lists_path, alert: t("nexus_ccs.lists.not_found") unless @list
  end

  # The records of a list, in the order it shows them (newest added first); records no longer in the index are left out. They
  # are wrapped as a response, as Blacklight's helpers (the Save control's bookmarks) read the page's documents from @response.
  def documents_in_order(ids)
    by_id = search_service.fetch(ids).index_by { |document| document.id.to_s }
    docs = ids.filter_map { |id| by_id[id.to_s]&._source }
    @response = Blacklight::Solr::Response.new({ "response" => { "docs" => docs, "numFound" => docs.size, "start" => 0 } }, {},
                                               blacklight_config: blacklight_config)
    @response.documents
  end
end
