# frozen_string_literal: true

# The pages of the static prototype (public/ in the repository root): home, help and about. Their text is in config/pages.yml (SitePages); the help sections are in app/views/pages/help.
class PagesController < ApplicationController
  layout "pages"

  def home; end

  # /help is one page with a section for each topic. The old /help?topic=<key> links go to the topic's own page or section.
  def help
    return redirect_to(advanced_search_catalog_path(anchor: "advanced-search-tips-title"), status: :moved_permanently) if params[:topic] == "search-tips" # the tips are on the Advanced Search page
    topic = HelpTopic.find(params[:topic] == "access" ? "contact-us" : params[:topic]) # "access" was the section's old key
    redirect_to topic.path(helpers), status: :moved_permanently if topic
  end
  def about; end
  def accessibility; end
  def privacy; end
  def language_in_records; end # "About the language in our records": what the de-bias notice on a record page is
end
