# frozen_string_literal: true

# Blacklight's own search history, laid out like the site's other pages: the breadcrumb strip, the page banner and the
# content container (views/search_history/index.html.erb). Blacklight's controller is otherwise unchanged, apart from
# destroy: a visitor can take one search out of their history (Blacklight only offers Clear).
class SearchHistoryController < ApplicationController
  include Blacklight::SearchHistory

  layout "pages"

  def destroy
    ids = Array(session[:history])
    search = Search.find_by(id: params[:id].to_i) if ids.include?(params[:id].to_i)
    return redirect_to(blacklight.search_history_path, notice: t("nexus_ccs.search_history.not_found")) unless search

    removed = [ search ] + SearchHistoryDays.redirect_origins(Search.where(id: ids).to_a, search)
    session[:history] = ids - removed.map(&:id)
    redirect_to blacklight.search_history_path, notice: t("nexus_ccs.search_history.removed")
  end
end
