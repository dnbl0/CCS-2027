# frozen_string_literal: true

# Saved searches (CCS-130): a visitor keeps a search from their history and opens it again later. The owner is the
# guest user of the session cookie (GuestBookmarks), created on the first save like a bookmark's.
class SavedSearchesController < ApplicationController
  layout "pages"

  def index
    @saved_searches = saved_searches.recent
  end

  def create
    search = searches_in_history.find_by(id: params[:search_id])
    return redirect_to(blacklight.search_history_path, alert: t("nexus_ccs.saved_searches.not_found")) unless search

    params_hash = search.query_params.to_h
    user = guest_owner
    saved = user.saved_searches.create(name: params[:name].presence || SavedSearch.default_name(params_hash), query_params: params_hash)

    if saved.persisted?
      redirect_to saved_searches_path, notice: t("nexus_ccs.saved_searches.saved")
    else
      redirect_to blacklight.search_history_path, alert: t("nexus_ccs.saved_searches.failure")
    end
  end

  def destroy
    saved_searches.find_by(id: params[:id])&.destroy
    redirect_to saved_searches_path, notice: t("nexus_ccs.saved_searches.removed")
  end

  private

  # Only searches in this visitor's own history can be saved
  def searches_in_history = Search.where(id: Array(session[:history]))

  def saved_searches
    id = session[:blacklight_guest_user_id]
    id ? SavedSearch.where(user_id: id) : SavedSearch.none
  end

  def guest_owner
    user = current_or_guest_user
    user.save! unless user.persisted?
    session[:blacklight_guest_user_id] = user.id
    user
  end
end
