require "application_system_test_case"
require_relative "../support/stub_records"

# The viewer layout of a record page (?layout=viewer) in a real browser: axe at a desktop and a phone width for each variant of a
# record, the pill's controls, the thumbnails switching the picture and the counter, and the plain address unchanged. The records
# are stand-ins given to the record page (the Solr core holds no withheld or sensitive record).
class RecordViewerLayoutSystemTest < ApplicationSystemTestCase
  module ViewerSolr
    mattr_accessor :documents

    def search_service
      return super unless ViewerSolr.documents

      real = super
      Struct.new(:docs, :real) { def fetch(id, *rest) = docs.fetch(id) { real.fetch(id, *rest) } }.new(ViewerSolr.documents, real)
    end
  end
  CatalogController.prepend(ViewerSolr)

  LARGE = StubRecords::OPEN_LARGE
  THUMBS = StubRecords::OPEN_THUMBS

  BASE = { "title_tsim" => [ "Untitled [Timber eucalypt specimen cabinet]" ], "format" => [ "Object" ], "object_type_ssim" => [ "chest of drawers" ],
           "production_date_ssim" => [ "[c. 1919]" ], "creator_ssim" => [ "Grimwade, Sir Wilfrid Russell" ], "material_ssim" => [ "timber" ],
           "classification_ssim" => [ "furniture" ], "subject_ssim" => [ "Architecture, design and furniture" ],
           "collection_ssim" => [ "University Art Collection" ], "accession_number_ssim" => [ "1973.0755" ],
           "description_tsim" => [ "A cabinet of drawers. " * 30 ], "credit_line_tsim" => [ "The University of Melbourne Art Collection" ],
           "rights_ssim" => [ "[Copyright] Rights held by the University" ] }.freeze

  VARIANTS = {
    "imageless" => {},
    "several images, open" => { "licence_type_ssim" => [ "Public domain - Copyright expired" ], "digital_asset_large_paths_ssim" => LARGE, "digital_asset_paths_ssim" => THUMBS },
    "view-only" => { "licence_type_ssim" => [ "Copyright - Current" ], "digital_asset_large_paths_ssim" => LARGE, "digital_asset_paths_ssim" => THUMBS },
    "request-only" => { "licence_type_ssim" => [ "ICIP Rights" ], "digital_asset_large_paths_ssim" => LARGE, "digital_asset_paths_ssim" => THUMBS },
    "sensitive" => { "licence_type_ssim" => [ "Copyright - Current" ], "restrictions_tsi" => [ "Culturally sensitive images" ],
                     "digital_asset_large_paths_ssim" => LARGE, "digital_asset_paths_ssim" => THUMBS }
  }.freeze

  SIZES = { "desktop" => [ 1440, 900 ], "phone" => [ 390, 844 ], "narrow" => [ 320, 800 ] }.freeze

  teardown do
    ViewerSolr.documents = nil
    page.current_window.resize_to(1440, 900)
  end

  def open_record(extra, size, layout: "viewer")
    ViewerSolr.documents = { "emu-9044" => SolrDocument.new(BASE.merge("id" => "emu-9044").merge(extra)).tap { |doc| doc.instance_variable_set(:@response, Blacklight::Solr::Response.new({ "response" => { "docs" => [] } }, {})) } }
    page.current_window.resize_to(*SIZES.fetch(size))
    visit "/catalog/emu-9044#{"?layout=#{layout}" if layout}"
    assert_selector "h1"
    assert_no_selector "html[aria-busy]"
  end

  VARIANTS.each do |name, extra|
    SIZES.each_key do |size|
      test "a #{name} record in the viewer layout at #{size} width has no axe violations, one h1, ordered headings and no sideways scroll" do
        open_record(extra, size)

        assert_selector ".viewer-page"
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ]) unless size == "narrow"
        assert_selector "h1", count: 1
        assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
        outline = page.evaluate_script("[...document.querySelectorAll('#main-container h1, #main-container h2, #main-container h3')].filter(e => e.getClientRects().length > 0).map(e => e.tagName + ' ' + e.textContent.trim())")
        levels = outline.map { |heading| heading[1].to_i }
        assert levels.each_cons(2).all? { |a, b| b <= a + 1 }, "headings skip a level: #{outline.inspect}"
        small = page.evaluate_script("[...document.querySelectorAll('.viewer-pill button, .viewer-media__thumb, .viewer-buttons a, .viewer-accordion > summary')].filter(e => e.getClientRects().length > 0).map(e => e.getBoundingClientRect()).filter(r => r.height < 44 || r.width < 44).length")
        assert_equal 0, small, "a control is smaller than 44px"
      end
    end
  end

  test "the pill zooms: a first zoom in starts the viewer and enables zoom out, reset goes home, and the keys line says what the keys do" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".viewer-pill", visible: true
    assert_selector ".viewer-pill button[aria-label='Zoom out'][disabled]"
    assert_selector ".viewer-media__keys", text: "+ and - to zoom, 0 to reset"

    find(".viewer-pill button[aria-label='Zoom in']").click
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all
    assert_equal "application", page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('role')")
    assert_equal "viewer-description", page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('aria-describedby')")
    assert_selector ".viewer-pill button[aria-label='Zoom out']:not([disabled])", wait: 8
    assert_selector "#viewer-navigator", visible: true
    find(".viewer-pill button[aria-label='Reset view']").click
    assert_selector ".viewer-pill button[aria-label='Zoom in']"
  end

  test "the mouse wheel is left to the page over the picture, switched on or not: no zoom, and no scroll trap" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    find(".viewer-pill button[aria-label='Zoom in']").click
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all
    assert_selector ".viewer-pill button[aria-label='Zoom out']:not([disabled])", wait: 8

    # dispatchEvent returns false when something called preventDefault on the event
    not_prevented = page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').dispatchEvent(new WheelEvent('wheel', { deltaY: 200, bubbles: true, cancelable: true }))")
    assert not_prevented, "the viewer swallows the mouse wheel over a zoomed picture"
  end

  test "the viewer stage keeps the page's light surface when zoom is switched on" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    find(".viewer-pill button[aria-label='Zoom in']").click
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all
    background = page.evaluate_script("getComputedStyle(document.querySelector('.viewer-media .deep-zoom__stage')).backgroundColor")
    page_surface = page.evaluate_script("getComputedStyle(document.querySelector('.viewer-page')).backgroundColor")
    assert_equal page_surface, background
  end

  test "linked values in the details rows are at least 24px high, so neighbours never crowd each other (WCAG 2.5.8)" do
    open_record(VARIANTS.fetch("view-only"), "desktop")
    assert_selector ".viewer-list__row dd a"
    small = page.evaluate_script("[...document.querySelectorAll('.viewer-list__row dd a')].filter(e => e.getClientRects().length > 0 && e.getBoundingClientRect().height < 24).length")
    assert_equal 0, small
  end

  test "a thumbnail switches the picture and the counter, and the strip marks the current one" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".viewer-media__counter", text: "1 of 2"
    page.evaluate_script("document.querySelector('.viewer-media__strip li:last-child .viewer-media__thumb').click()")
    assert_selector ".viewer-media__counter", text: "2 of 2"
    assert_selector ".viewer-media__thumb.is-current[aria-current=true]", count: 1
    assert_equal LARGE.last, page.evaluate_script("document.querySelector('.digital-assets__image').getAttribute('src')").split("?").first
  end

  test "the full screen button is in the pill and the default address is not the viewer layout" do
    open_record(VARIANTS.fetch("view-only"), "desktop")
    assert_selector ".viewer-pill button[aria-label='Full screen']", visible: :all
    assert_no_selector "a[download]"

    open_record(VARIANTS.fetch("view-only"), "desktop", layout: nil)
    assert_no_selector ".viewer-page"
    assert_selector ".record-hero"
  end
end
