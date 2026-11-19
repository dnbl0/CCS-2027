# frozen_string_literal: true

# What the discovery controllers (SimilarController, DiscoverController) share. They are CatalogControllers, so the result cards
# draw as they do on a results page; the cards are given the documents as a response, which the Save control's helpers read.
# A Solr failure never breaks the page that asked: a lazy frame gets "204 No Content" and so stays empty.
module DiscoveryFragment
  extend ActiveSupport::Concern

  included do
    skip_before_action :apply_search_defaults, raise: false
    rescue_from Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::InvalidRequest, Faraday::Error, with: :nothing_to_show
  end

  private

  # A fragment is not a page: kept out of search results and not followed (the pages it appears in are indexed as they are)
  def fragment_not_for_indexing
    request.env["ccs.robots"] = [ RobotsPolicy::NOINDEX_NOFOLLOW, (RobotsPolicy::AI if BotControls.enabled?) ].compact.join(", ")
  end

  def nothing_to_show(error)
    Discovery.log_failure(controller_name.humanize, error)
    head :no_content
  end

  # An id the index does not hold is a 404. Asked from a lazy Turbo frame on a record page, the 404 has no body: the site's error
  # page carries turbo-visit-control "reload", which would make Turbo replace the whole record page with it (the frame then simply
  # stays empty, controllers/lazy_frame_controller.js). Asked directly, it is the ordinary Not Found.
  def record_not_found!
    return head(:not_found) if request.headers["Turbo-Frame"].present?

    raise ActionController::RoutingError, "Not Found"
  end

  # Blacklight's helpers read the page's documents from @response
  def wrap_documents(documents)
    docs = documents.map(&:_source)
    @response = Blacklight::Solr::Response.new({ "response" => { "docs" => docs, "numFound" => docs.size, "start" => 0 } }, {},
                                               blacklight_config: blacklight_config)
  end
end
