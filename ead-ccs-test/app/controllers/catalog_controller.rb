# frozen_string_literal: true

require "faraday"

# Blacklight controller that handles searches and document requests
class CatalogController < ApplicationController
  include Blacklight::Catalog
  include BlacklightRangeLimit::ControllerOverride
  include QueryRules

  # The results open in the default view (mosaic) every time. Blacklight would remember the last view the
  # visitor chose in the session and open every later search that way; here only ?view= in the URL changes it.
  # (A block here, so it comes after, and wins over, the gem's own helper.)
  helper do
    def document_index_view_type(query_params = params || {})
      view = query_params[:view]
      view.present? && document_index_views.key?(view.to_sym) ? view.to_sym : default_document_index_view_type
    end
  end

  # Solr down, slow or refusing a request: say so, instead of a stack trace. The pages that do not search (home, help...)
  # keep working. Timeouts come from config/blacklight.yml.
  rescue_from BlacklightRangeLimit::InvalidRange, with: :invalid_date_range
  rescue_from Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::RepositoryTimeout, Blacklight::Exceptions::InvalidRequest, Faraday::TimeoutError, Faraday::ConnectionFailed, with: :search_unavailable

  # Retries a zero-result search using Solr's spelling collation
  self.search_service_class = ::SearchService

  configure_blacklight do |config|
    # One design, the light one, whatever the browser or device is set to: no colour mode switching (see layouts/_light_theme)
    config.dark_mode_support = false

    # Results per page; the per_page widget offers these and the first request uses the default.
    config.per_page = [ 12, 24, 40, 96 ]
    config.default_per_page = 40

    # Blacklight's default is 'select', which solrconfig.xml now declares.
    # config.solr_path = 'select'

    # solr field configuration for search results/index views
    config.header_component = NexusCcs::HeaderComponent

    config.index.title_field = "title_tsim"

    # Result views: the built-in list, plus the mosaic (masonry) from blacklight-gallery (no grid view).
    # Records with a digital asset show it in both views; the rest show a placeholder in the mosaic
    # (and nothing in the list). Mosaic placeholders vary in shape, as real images do, so the masonry
    # layout stays a mosaic where images are missing.
    config.index.thumbnail_field = :thumbnail_path_ssi
    mosaic_placeholder = lambda do |document, image_options|
      shape = %w[placeholder-thumbnail.svg placeholder-portrait.svg placeholder-square.svg][document.id.sum % 3]
      ActionController::Base.helpers.image_tag(shape, image_options)
    end
    config.view.list.document_component = NexusCcs::ResultCardComponent
    config.view.list.icon = NexusCcs::ListViewIconComponent
    # Mosaic is the default view; List is the other button
    config.view.masonry(document_component: NexusCcs::ResultCardComponent, default: true,
      icon: NexusCcs::MasonryViewIconComponent, default_thumbnail: mosaic_placeholder)
    config.index.display_type_field = "format"

    # Bookmarks are the "Save / Saved" control (visitors need no login: GuestBookmarks). The result cards place it
    # themselves (NexusCcs::ResultCardComponent), so the tool is registered for Blacklight but not drawn by the title.
    config.bookmark_icon_component = NexusCcs::Icons::BookmarkComponent
    config.add_results_document_tool(:bookmark, component: NexusCcs::SaveControlComponent, if: :render_bookmarks_control?)

    # Below 992px the sidebar is a drawer; this button opens it.
    config.index.sidebar_component = NexusCcs::FilterSidebarComponent
    config.index.constraints_component = NexusCcs::ConstraintsComponent
    config.add_results_collection_tool(:filters_toggle, component: NexusCcs::FilterToggleComponent)
    config.add_results_collection_tool(:sort_widget)
    config.add_results_collection_tool(:per_page_widget)
    config.add_results_collection_tool(:view_type_group)

    # The record page draws the control in its summary (NexusCcs::RecordDocumentComponent); the sidebar of show tools
    # is hidden on the redesigned page, so it is not registered there a second time.
    # config.add_show_tools_partial(:email, callback: :email_action, validator: :email_params_valid?)
    # config.add_show_tools_partial(:sms, if: :render_sms_action?, callback: :sms_action, validator: :sms_params_valid?)
    # Links out to the record in its source system, behind a "you're leaving this
    # site" interstitial. Guarded here rather than by the component's render?,.
    config.add_show_tools_partial(:view_full_record, component: NexusCcs::ViewFullRecordComponent,
      if: ->(_context, _config, options) {  # so a record with no URL doesn't leave an empty <li>
        NexusCcs::ViewFullRecordComponent.url_for(options[:document]).present?
      })
    config.add_show_tools_partial(:citation)

    # (The nav's bookmark link is the saved bar, NexusCcs::SavedBarComponent.)
    config.add_nav_action(:search_history, partial: "blacklight/nav/search_history")

    # solr field configuration for document/show views
    config.show.title_field = "title_tsim"
    config.show.display_type_field = "format"

    # Puts "Start over"/"Back to search" on the same row as the prev/next
    # pagination. Subclasses the Blacklight component and only swaps the template.
    config.show.document_header_component = NexusCcs::DocumentHeaderComponent

    # The record page body after the CCS UI "Record-detail": media, summary, details, persistent link, copyright.
    config.show.document_component = NexusCcs::RecordDocumentComponent

    # Between a record's title and its details: the digital assets and a summary line.
    config.show.document_embed_component = NexusCcs::RecordEmbedComponent

    # After the details: the persistent link, then how to contact the collection team (CCS-47).
    config.show.partials = [ :persistent_link, :contact_collection ]

    CatalogConfig::Facets.apply(config)

    CatalogConfig::RecordFields.apply(config)

    CatalogConfig::SearchFields.apply(config)

    config.advanced_search.enabled = true

    # Set up a default advanced search configuration by using the current
    # search_fields and facet_fields configs.
    if config.advanced_search.enabled
      config.copy_search_field_config_to_advanced!
      config.copy_facet_field_config_to_advanced!
      CatalogConfig::Facets.keep_pending_out_of_advanced_request(config)

      # Blacklight asks Solr for every value of every filter on the form ("facet.limit": -1): with the full collections that was a page
      # of 8 MB and about 15,000 checkboxes, far too long to use (and too slow for a screen reader or a phone). Each filter lists its
      # most common values (facet.sort is count) in a scrolling list; every value is still reachable through the filters on the results page.
      advanced_facet_limit = 100
      config.advanced_search.form_solr_parameters.each_key do |key|
        config.advanced_search.form_solr_parameters[key] = advanced_facet_limit if key.match?(/\Af\..+\.facet\.limit\z/)
      end
    end

    # ================================================================
    # Sorting
    # date_start_isi rather than pub_date_si
    # title_si rather than author_si
    # ================================================================
    config.add_sort_field "relevance", sort: "score desc, title_si asc", label: "relevance"
    config.add_sort_field "date-desc", sort: "date_start_isi desc, title_si asc", label: "date (newest)"
    config.add_sort_field "date-asc", sort: "date_start_isi asc, title_si asc", label: "date (oldest)"
    config.add_sort_field "title", sort: "title_si asc", label: "title (A-Z)"
    config.add_sort_field "title-desc", sort: "title_si desc", label: "title (Z-A)"

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 100

    # The marker left by taking the default Digital asset filter off (DigitalAssetFilterField) travels on every link of the
    # search: the view, sort, per-page and pagination links are built from the search state, which drops anything not listed.
    config.search_state_fields += [ :any_assets ]

    # Configuration for autocomplete suggester
    config.autocomplete_enabled = true
    config.autocomplete_path = "suggest"
  end

  # Home page, the Advanced search form again, or the default Digital asset filter: the rules are SearchDefaults'
  before_action :apply_search_defaults, only: :index

  private

  def apply_search_defaults
    outcome, detail = SearchDefaults.decide(request.query_parameters, html: request.format.html?, get: request.get?,
                                            catalog: controller_name == "catalog")
    case outcome
    when :home then redirect_to root_path
    when :advanced_search_again then redirect_to advanced_search_catalog_path(op: detail), flash: { advanced_search_error: true }
    when :search then redirect_to search_action_url(detail)
    end
  end

  # From later than To (a hand-edited address): the search runs without the date range, and says so.
  def invalid_date_range(_error)
    if request.format.json?
      render json: { error: "The From year must not be later than the To year." }, status: :unprocessable_content
    else
      redirect_to search_action_url(request.query_parameters.except("range")), alert: "The From year must not be later than the To year, so the date range was not used."
    end
  end

  def search_unavailable(error)
    Rails.logger.error("Search unavailable: #{error.class}: #{error.message}")
    response.headers["Retry-After"] = ErrorsController::RETRY_AFTER.fetch("503").to_s
    respond_to do |format|
      format.html { render "catalog/unavailable", status: :service_unavailable }
      format.json { render json: { error: "Search is unavailable. Please try again shortly." }, status: :service_unavailable }
      format.any { head :service_unavailable }
    end
  end
end
