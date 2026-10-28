# frozen_string_literal: true

module NexusCcs
  # The UoM header for the branded stock record page (BrandedStockCatalogController): the site's header, unchanged,
  # with the breadcrumb of a record page and no search banner or title band, as the page under it is Blacklight's own
  # (PageChrome.stock_record).
  class StockHeaderComponent < HeaderComponent
    def chrome = @chrome ||= PageChrome.stock_record(record_title: record_title, results_url: search_action_url)
  end
end
