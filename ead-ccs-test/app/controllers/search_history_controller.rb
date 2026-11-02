# frozen_string_literal: true

# Blacklight's own search history, laid out like the site's other pages: the breadcrumb strip, the page banner and the
# content container (views/search_history/index.html.erb). Blacklight's controller is otherwise unchanged.
class SearchHistoryController < ApplicationController
  include Blacklight::SearchHistory

  layout "pages"
end
