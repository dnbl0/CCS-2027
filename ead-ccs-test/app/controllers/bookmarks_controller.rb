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

  # The citations of the saved records (CCS-137)
  def citations
    render_citations(Array(action_documents), heading: t("nexus_ccs.saved.list_title"), back_path: bookmarks_path,
                                              back_label: t("nexus_ccs.cite_page.back_to_saved"))
  end

  private

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
