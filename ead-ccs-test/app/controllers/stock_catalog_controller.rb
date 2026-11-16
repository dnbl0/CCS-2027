# frozen_string_literal: true

# The record page as Blacklight ships it (/stock/:id), for comparing the site's own record page against.
# Deliberately not an ApplicationController (no guest bookmarks, country acknowledgement) and not the
# CatalogController (no NexusCcs components); every setting below is Blacklight's default or the generator's.
class StockCatalogController < ActionController::Base
  include Blacklight::Controller
  include Blacklight::Catalog

  layout "stock_blacklight"

  # A record taken out of the site (CCS-112) is a 410 Gone page
  before_action(only: %i[show citation]) { SuppressedRecord.guard!(params[:id]) }

  # openseadragon_picture_tag, used by blacklight-gallery's OpenSeadragon viewer
  helper Openseadragon::OpenseadragonHelper

  # The app's helpers/blacklight_helper.rb widens the record page's container; this is the gem's own definition.
  helper do
    def container_classes = blacklight_config.full_width_layout ? "container-fluid" : "container"
  end

  # The gem's own views come first, so the app's overrides of them (catalog/show, shared/footer...) are not used.
  prepend_view_path Blacklight::Engine.root.join("app/views")

  # Blacklight's views live under catalog/, not stock_catalog/; the stock page's own (and its subclasses') come first.
  def self.local_prefixes = [ controller_path, "stock_catalog", "catalog" ].uniq

  # This page has no search of its own: the search box and "Back to search" go to the real catalog, the same way
  # the gem's own Blacklight::Bookmarks does.
  # (Blacklight adds only_path to the options of search_action_path; the catalog's own helpers do not take it.)
  def search_action_url(options = {}) = search_catalog_url(search_action_options(options))

  def search_action_path(options = {}) = search_catalog_path(search_action_options(options))

  def search_action_options(options) = (options.respond_to?(:to_h) ? options.to_h : {}).except(:only_path, :controller, :action)
  private :search_action_options

  configure_blacklight do |config|
    # One design, the light one, whatever the browser or device is set to (the only change from the gem's defaults here)
    config.dark_mode_support = false
    config.show.title_field = "title_tsim"
    config.show.display_type_field = "format"
    # The record's digital assets in blacklight-gallery's OpenSeadragon viewer (zoom, pan, full page; a paging strip
    # when there are several images), above the details: the embed slot sits between the title and the metadata.
    # The viewer is the gem's own component; the subclass only gives it the record's image URLs.
    config.show.document_embed_component = StockOpenseadragonEmbedComponent

    # One row for every field of the CCS Field Labels sheet, a muted "Not available" where the record has no
    # value (see StockRecordFields), plus the Copyright card's caption.
    StockRecordFields.apply(config)

    # The details list under an "Object details" heading, laid out as rows of a table, from Blacklight's own
    # components and Bootstrap's utility classes.
    config.show.document_metadata_component = StockObjectDetailsComponent
    config.show.document_component = StockDocumentComponent
    config.show.document_title_component = StockTitleComponent
    config.show.document_header_component = StockPageHeaderComponent
    config.show.sidebar_component = StockSidebarComponent
  end
end
