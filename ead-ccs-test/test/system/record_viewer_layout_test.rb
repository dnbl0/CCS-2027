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

  SIZES = { "desktop" => [ 1440, 900 ], "tablet" => [ 900, 768 ], "phone" => [ 390, 844 ], "narrow" => [ 320, 800 ] }.freeze

  teardown do
    ViewerSolr.documents = nil
    page.current_window.resize_to(1440, 900)
  end

  def open_record(extra, size, layout: "viewer")
    ViewerSolr.documents = { "emu-9044" => SolrDocument.new(BASE.merge("id" => "emu-9044").merge(extra)).tap { |doc| doc.instance_variable_set(:@response, Blacklight::Solr::Response.new({ "response" => { "docs" => [] } }, {})) } }
    page.current_window.resize_to(*SIZES.fetch(size))
    visit "/catalog/emu-9044#{"?layout=#{layout}" if layout}"
    assert_selector "h1", visible: :all
    assert_no_selector "html[aria-busy]"
  end

  # Whether a phone-sized layout shows the data view: the panel's content is only in the page then
  def show_data
    click_button "Show data"
    assert_selector ".viewer-data__sections", visible: true
  end

  VARIANTS.each do |name, extra|
    SIZES.each_key do |size|
      test "a #{name} record in the viewer layout at #{size} width has no axe violations, one h1, ordered headings and no sideways scroll" do
        open_record(extra, size)

        assert_selector ".viewer-page"
        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ]) unless size == "narrow"
        if size.in?(%w[phone tablet narrow]) && name != "imageless"
          show_data
          assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ]) unless size == "narrow"
        end
        assert_selector "h1", count: 1, visible: :all
        assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
        outline = page.evaluate_script("[...document.querySelectorAll('#main-container h1, #main-container h2, #main-container h3')].filter(e => e.getClientRects().length > 0).map(e => e.tagName + ' ' + e.textContent.trim())")
        levels = outline.map { |heading| heading[1].to_i }
        assert levels.each_cons(2).all? { |a, b| b <= a + 1 }, "headings skip a level: #{outline.inspect}"
        small = page.evaluate_script("[...document.querySelectorAll('.viewer-pill button, .viewer-strip button, .viewer-strip a, .viewer-media__thumb, .viewer-toggle, .viewer-switch button, .viewer-bar a, .viewer-bar button')].filter(e => e.getClientRects().length > 0).map(e => e.getBoundingClientRect()).filter(r => r.height < 44 || r.width < 44).length")
        assert_equal 0, small, "a control is smaller than 44px"
        links = page.evaluate_script("[...document.querySelectorAll('.viewer-list__row dd a')].filter(e => e.getClientRects().length > 0 && e.getBoundingClientRect().height < 24).length")
        assert_equal 0, links, "a linked value is under 24px high"
      end
    end
  end

  test "controls never cover each other or the sensitivity notice, at every width" do
    SIZES.each_key do |size|
      open_record(VARIANTS.fetch("several images, open"), size)
      boxes = page.evaluate_script("[...document.querySelectorAll('.viewer-pill button, .viewer-strip button, .viewer-strip a, .viewer-toggle')].filter(e => { if (e.getClientRects().length === 0) return false; const r = e.getBoundingClientRect(); const hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); return hit && (e === hit || e.contains(hit)) }).map(e => { const r = e.getBoundingClientRect(); return [r.left, r.top, r.right, r.bottom] })")
      boxes.combination(2).each do |a, b|
        overlap = a[0] < b[2] - 1 && b[0] < a[2] - 1 && a[1] < b[3] - 1 && b[1] < a[3] - 1
        assert_not overlap, "two controls overlap at #{size}: #{a} #{b}"
      end
    end

    open_record(VARIANTS.fetch("sensitive"), "desktop")
    gate = page.evaluate_script("document.querySelector('.viewer-media .sensitivity-gate').getBoundingClientRect().toJSON()")
    strip = page.evaluate_script("document.querySelector('.viewer-strip').getBoundingClientRect().toJSON()")
    assert_operator gate["bottom"], :<=, strip["top"] + 1, "the notice sits inside the stage, above the strip"
  end

  test "the page is a split from 1024px wide, the panel scrolls on its own, and below that the viewer and the data are two views" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".viewer-app .viewer-data h1"
    panel, stage = %w[.viewer-data .viewer-stage].map { |selector| page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    assert_operator stage["left"], :>=, panel["right"] - 1
    assert_in_delta panel["top"], stage["top"], 2
    assert_equal "auto", page.evaluate_script("getComputedStyle(document.querySelector('.viewer-data__scroll')).overflowY")
    assert_equal [ "Object details", "Collection and provenance", "Rights and access", "About this record" ], page.all(".viewer-data h2").map(&:text)
    assert_no_selector "details"
    assert_no_selector ".viewer-switch", visible: true

    open_record(VARIANTS.fetch("several images, open"), "phone")
    assert_selector ".viewer-switch button[aria-pressed=true]", text: "Show images"
    assert_selector ".viewer-stage", visible: true
    assert_no_selector ".viewer-data__sections", visible: true
    assert_selector ".viewer-data h1", visible: true # the title shows on both views
    assert_no_selector ".viewer-toggle", visible: true
    show_data
    assert_no_selector ".viewer-stage", visible: true
    assert_selector ".viewer-switch button[aria-pressed=true]", text: "Show data"
    assert_selector ".viewer-bar a", text: "New search"
    click_button "Show images"
    assert_selector ".viewer-stage", visible: true
    assert_no_selector ".viewer-data__sections", visible: true
  end

  test "the round toggle on the dividing line collapses and expands the panel; focus stays on it and the hidden panel is out of the tab order" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".viewer-toggle[aria-expanded=true][aria-label='Show larger image']"
    before = page.evaluate_script("document.querySelector('.viewer-stage').getBoundingClientRect().width")

    find(".viewer-toggle").click
    assert_selector ".viewer-toggle[aria-expanded=false][aria-label='Show data']"
    assert_no_selector ".viewer-data", visible: true
    assert_equal "viewer-toggle", page.evaluate_script("document.activeElement.className")
    assert_operator page.evaluate_script("document.querySelector('.viewer-stage').getBoundingClientRect().width"), :>, before + 200

    find(".viewer-toggle").click
    assert_selector ".viewer-toggle[aria-expanded=true]"
    assert_selector ".viewer-data", visible: true
    assert_selector ".viewer-data__sections", visible: true
  end

  test "the viewer starts on its own, without taking focus, and the buttons zoom with limits; the key 0 resets" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
    assert_not_equal "application", page.evaluate_script("document.activeElement.getAttribute('role')"), "the viewer took focus on load"
    assert_equal "application", page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('role')")
    assert_equal "viewer-description", page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('aria-describedby')")
    assert_selector ".viewer-pill button[aria-label='Zoom out'][disabled]" # at home there is nothing to zoom out of

    find(".viewer-pill button[aria-label='Zoom in']").click
    assert_selector ".viewer-pill button[aria-label='Zoom out']:not([disabled])", wait: 8
    assert_selector ".deep-zoom.is-zoomed #viewer-navigator", visible: true, wait: 8
    assert_equal "hidden", page.evaluate_script("document.querySelector('.deep-zoom').classList.remove('is-zoomed'), getComputedStyle(document.querySelector('#viewer-navigator')).visibility"), "the navigator is only for a zoomed picture"
    page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').focus()")
    page.driver.browser.keyboard.type("0")
    assert_selector ".viewer-pill button[aria-label='Zoom out'][disabled]", wait: 8
  end

  test "the mouse wheel is left to the page over the picture: no zoom, and no scroll trap" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
    not_prevented = page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').dispatchEvent(new WheelEvent('wheel', { deltaY: 200, bubbles: true, cancelable: true }))")
    assert not_prevented, "the viewer swallows the mouse wheel"
    assert_selector ".viewer-pill button[aria-label='Zoom out'][disabled]" # and it did not zoom
  end

  test "the stage is light, never dark, except in full screen" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
    stage = page.evaluate_script("getComputedStyle(document.querySelector('.viewer-stage')).backgroundColor").scan(/\d+/).first(3).map(&:to_i)
    assert_operator stage.min, :>=, 230
    zoom = page.evaluate_script("getComputedStyle(document.querySelector('.viewer-media .deep-zoom__stage')).backgroundColor").scan(/\d+/).first(3).map(&:to_i)
    assert_operator zoom.min, :>=, 230
  end

  test "thumbnails, Previous and Next change the picture in sequence; the arrows stop at the ends and the change is announced" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".viewer-strip button[aria-label='Previous image'][disabled]"
    assert_selector "[data-media-viewer-target=counter]", text: "Image 1 of 2", visible: :all

    find(".viewer-strip button[aria-label='Next image']").click
    assert_selector "[data-media-viewer-target=counter]", text: "Image 2 of 2", visible: :all
    assert_selector ".viewer-media__thumb.is-current[aria-label='Display image 2 of 2'][aria-current=true]", count: 1
    assert_selector ".viewer-strip button[aria-label='Next image'][disabled]"
    assert_equal LARGE.last, page.evaluate_script("document.querySelector('.digital-assets__image').getAttribute('src')").split("?").first
    assert_equal LARGE.last, page.evaluate_script("document.querySelector('.viewer-strip__use').getAttribute('href')").split("?").first, "Use this image follows the current image"

    find(".viewer-strip button[aria-label='Previous image']").click
    assert_selector "[data-media-viewer-target=counter]", text: "Image 1 of 2", visible: :all
    find(".viewer-media__thumb[aria-label='Display image 2 of 2']").click
    assert_selector ".viewer-media__thumb.is-current[aria-label='Display image 2 of 2']"
  end

  test "Use this image: an open record downloads, a view-only record opens its rights in the panel, a request-only record asks" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".viewer-strip a.viewer-strip__use[download]", text: "Use this image"

    open_record(VARIANTS.fetch("view-only"), "phone")
    find(".viewer-strip__use").click
    assert_selector ".viewer-data__sections", visible: true
    assert_selector "#viewer-rights", visible: true
    assert_no_selector "a[download]"

    open_record(VARIANTS.fetch("request-only"), "desktop")
    assert_selector ".viewer-strip__use[href*=access_requests]"
    assert_no_selector ".viewer-pill", visible: :all
  end

  test "Share opens the Share and embed dialog and Print calls the browser's print" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    page.execute_script("window.__printed = 0; window.print = function () { window.__printed += 1 }")
    find(".viewer-bar button[aria-label='Print']").click
    assert_equal 1, page.evaluate_script("window.__printed")

    find(".viewer-bar .share__button").click
    assert_selector "dialog[open]"
  end

  test "the default address is not the viewer layout" do
    open_record(VARIANTS.fetch("view-only"), "desktop", layout: nil)
    assert_no_selector ".viewer-page"
    assert_selector ".record-hero"
  end
end
