# frozen_string_literal: true

# Blacklight 9.0.0's own BookmarksController, with verify_user fixed: the gem calls
# `action`, which Rails 8.1 no longer resolves, so every /bookmarks request raised
# NameError. Remove this override when Blacklight ships the `action_name` fix.
class BookmarksController < CatalogController
  include Blacklight::Bookmarks
  include CitationsPage

  # The saved list is laid out like the content pages (page banner, container), not Blacklight's results layout
  layout "pages"

  before_action :remember_guest_user, only: %i[create update]
  # A double click on Save sends two requests: they take turns (a lock on the visitor's row), so the second finds the first's bookmark
  # and no record is saved twice (there is no unique index on the Blacklight bookmarks table)
  around_action :one_at_a_time, only: %i[create update]
  before_action :limit_saved, only: %i[create update]

  # A visitor may keep this many saved records (the saved records page fetches them all from Solr in one request)
  MAX_SAVED = 500

  # The citations of the saved records (CCS-137)
  def citations
    render_citations(Array(action_documents), heading: t("nexus_ccs.saved.list_title"), back_path: bookmarks_path,
                                              back_label: t("nexus_ccs.cite_page.back_to_saved"))
  end

  private

  def limit_saved
    incoming = params[:bookmarks].respond_to?(:size) ? params[:bookmarks].size : 1
    return if current_or_guest_user.bookmarks.count + incoming <= MAX_SAVED

    message = t("nexus_ccs.saved.too_many", count: MAX_SAVED)
    return render(json: [ message ], status: :unprocessable_content) if request.xhr?

    redirect_back_or_to bookmarks_path, alert: message
  end

  def one_at_a_time(&block) = current_or_guest_user.with_lock(&block)

  # Create the guest's row on the first save and remember it in the (30-day) session cookie.
  def remember_guest_user
    user = current_or_guest_user
    user.save! unless user.persisted?
    session[:blacklight_guest_user_id] = user.id
  end

  def verify_user
    unless current_or_guest_user || (action_name == "index" && token_or_current_or_guest_user)
      flash[:notice] = I18n.t("blacklight.bookmarks.need_login")
      raise Blacklight::Exceptions::AccessDenied
    end
  end
end
