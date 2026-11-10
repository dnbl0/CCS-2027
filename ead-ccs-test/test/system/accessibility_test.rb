require "application_system_test_case"

# axe-core (WCAG 2.1 A and AA) over the pages and the states people reach by clicking
class AccessibilityTest < ApplicationSystemTestCase
  setup { page.driver.set_cookie("country_acknowledged", "1") }

  PAGES = {
    "home" => "/",
    "help" => "/help",
    "indigenous cultural data" => "/help/indigenous-data",
    "contact" => "/contact",
    "advanced search" => "/catalog/advanced"
  }.freeze

  PAGES.each do |name, path|
    test "#{name} has no axe violations" do
      visit path
      assert_accessible
    end
  end

  test "the check fails on a page with a violation, so a pass means something" do
    visit "/contact"
    page.execute_script("document.body.insertAdjacentHTML('beforeend', '<img src=\"/icon.png\"><button></button>')")

    error = assert_raises(Minitest::Assertion) { assert_accessible }
    assert_match(/image-alt/, error.message)
    assert_match(/button-name/, error.message)
  end

  test "search results have no axe violations" do
    visit search_catalog_path(any_assets: "1", q: "skull")
    assert_selector ".result-card"
    assert_accessible
  end

  test "a record page has no axe violations" do
    visit search_catalog_path(any_assets: "1", q: "skull")
    first(".result-card .document-title-heading a").click
    assert_no_selector ".result-card" # the results page has an h1 too: wait until the record page has replaced it
    assert_selector "h1"
    assert_no_selector "html[aria-busy]" # Turbo marks the page busy while it navigates; axe flags that on the html element
    assert_accessible
  end

  # The new record pages (/stock/:id and /branded-stock/:id), which exist for the two records of StockRecords only: one with several images and
  # one with a single image. They are given stand-in records with images, a licence, a rights note and the other fields the page draws, because
  # the test index has no digital asset files, so the viewer, thumbnails, tabs and the media metadata modal would not be on the page to check.
  # axe runs in every state people reach by clicking: the default tab, each other tab, and the modal. What axe cannot judge (the image's text
  # alternative, the tab order and focus rings) is asserted in test/controllers/stock_catalog_test.rb.
  module StockSolr
    mattr_accessor :documents

    def search_service
      return super unless StockSolr.documents

      Struct.new(:doc) { def fetch(*) = doc }.new(StockSolr.documents.fetch(params[:id]))
    end
  end
  StockCatalogController.prepend(StockSolr)
  BrandedStockCatalogController.prepend(StockSolr)

  def stock_document(id, images, licence: "Public domain - Copyright expired")
    fields = { "id" => id, "title_tsim" => [ "Untitled [Timber eucalypt specimen cabinet]" ], "format" => [ "Object" ],
               "object_type_ssim" => [ "chest of drawers", "Item" ], "production_date_ssim" => [ "[c. 1919—20]" ],
               "creator_display_ssim" => [ "Grimwade, Sir Wilfrid Russell CBE (1879 \u2013 1955)" ], "production_place_ssim" => [ "Oceania", "Australia" ],
               "accession_number_ssim" => [ "1973.0755.000.A.000.L" ], "collection_ssim" => [ "University Art Collection" ],
               "classification_ssim" => [ "Architecture, buildings and furniture", "furniture - storage / display" ], "subject_ssim" => [ "Architecture, design and furniture" ],
               "licence_type_ssim" => [ licence ], "credit_line_tsim" => [ "The University of Melbourne Art Collection" ],
               "rights_ssim" => [ "[Public domain - Copyright expired] Public Domain / no known copyright restrictions" ],
               "digital_asset_large_paths_ssim" => images.map { |name| "/digital-assets/large/#{name}.jpg" },
               "digital_asset_paths_ssim" => images.map { |name| "/digital-assets/thumbs/#{name}.jpg" } }
    SolrDocument.new(fields).tap { |doc| doc.instance_variable_set(:@response, Blacklight::Solr::Response.new({ "response" => { "docs" => [] } }, {})) }
  end

  teardown { StockSolr.documents = nil }

  # Bootstrap fades a tab pane and a modal in; axe measured mid-fade reads washed-out colours. Waits until the element is fully opaque.
  def wait_until_opaque(selector)
    Timeout.timeout(5) { sleep 0.05 until page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).opacity") == "1" }
  end

  StockRecords::IDS.product(%w[stock branded-stock]).each do |id, prefix|
    test "the new record page /#{prefix}/#{id} has no axe violations in any tab or with the media metadata modal open" do
      StockSolr.documents = { "emu-9044" => stock_document("emu-9044", %w[a b c d]), "vernon-MHM00394" => stock_document("vernon-MHM00394", %w[a]) }
      visit "/#{prefix}/#{id}"
      assert_selector "h1"
      assert_selector "[role=img][aria-label]"
      assert_selector "[data-media-thumbnails] button", count: 4 if id == "emu-9044"
      assert_accessible

      %w[copyright permalink].each do |tab|
        find("##{tab}-tab").click
        assert_selector "##{tab}-pane.show.active"
        wait_until_opaque("##{tab}-pane")
        assert_accessible
      end

      find("button[data-bs-toggle=modal][aria-label='Media metadata']").click
      assert_selector ".modal.show"
      wait_until_opaque(".modal.show")
      assert_accessible
    end
  end

  # Content classification (AccessPolicy): the notice for a view-only record (beside the viewer) and a request record (in place of it)
  { "view-only" => "Copyright - Current", "request" => "ICIP Rights" }.each do |tier, licence|
    test "a #{tier} record page has the access notice and no axe violations" do
      StockSolr.documents = { "emu-9044" => stock_document("emu-9044", %w[a b], licence: licence) }
      visit "/stock/emu-9044"
      assert_selector "h1"
      assert_selector ".access-notice a[href='/access_requests/new?document_id=emu-9044']"
      assert_no_selector ".access-notice [role], .access-notice [aria-live]"
      assert_selector "picture[data-openseadragon]" if tier == "view-only"
      assert_no_selector "picture[data-openseadragon]" if tier == "request"
      # aria-hidden-focus is the closed media metadata modal, which the page-wide test above also trips here (not this change's)
      assert_accessible(except: [ "aria-hidden-focus" ])
    end
  end

  test "the home page with the Acknowledgement of Country open has no axe violations" do
    page.driver.clear_cookies
    visit root_path
    assert_selector "#country-acknowledgement[open]"
    assert_accessible
  end
end
