require "application_system_test_case"
require_relative "../support/stub_records"

# The record page's layout (the approved split layout) in every variant a record can be in, at a desktop and a phone width: axe (WCAG
# 2.2 AA rules too), no sideways scroll, one h1, the headings in order, nothing sticky but the media column on a wide screen, and
# targets at least 24px. The records are stand-ins (the Solr core
# holds no sensitive or withheld record, and no record of each kind by a known id), given to the record page the way the stock pages'
# test does (accessibility_test.rb): the controller's search service answers with them.
class RecordPageLayoutSystemTest < ApplicationSystemTestCase
  module RecordSolr
    mattr_accessor :documents

    def search_service
      return super unless RecordSolr.documents

      # The stand-in answers for its own records; any other id (a related record, the visitor's history) goes to the real index
      real = super
      Struct.new(:docs, :real) { def fetch(id, *rest) = docs.fetch(id) { real.fetch(id, *rest) } }.new(RecordSolr.documents, real)
    end
  end
  CatalogController.prepend(RecordSolr)

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
    "one image, open" => { "licence_type_ssim" => [ "Public domain - Copyright expired" ], "digital_asset_large_paths_ssim" => LARGE.first(1), "digital_asset_paths_ssim" => THUMBS.first(1) },
    "several images, view-only" => { "licence_type_ssim" => [ "Copyright - Current" ], "digital_asset_large_paths_ssim" => LARGE, "digital_asset_paths_ssim" => THUMBS },
    "request-only" => { "licence_type_ssim" => [ "ICIP Rights" ], "digital_asset_large_paths_ssim" => LARGE, "digital_asset_paths_ssim" => THUMBS },
    "sensitive" => { "licence_type_ssim" => [ "Copyright - Current" ], "restrictions_tsi" => [ "Culturally sensitive images" ],
                     "digital_asset_large_paths_ssim" => LARGE, "digital_asset_paths_ssim" => THUMBS },
    # As the DAM sync writes them (Dam::SolrWriter): the index holds only the viewable assets' addresses, every asset's metadata
    "per-asset licences, one shown and one withheld" => {
      "digital_asset_metadata_ssm" => [ { "licence" => "CC BY", "format" => "image", "tier" => "open" }, { "licence" => "None", "format" => "image", "tier" => "request" } ].map(&:to_json),
      "digital_asset_large_paths_ssim" => LARGE.first(1), "digital_asset_paths_ssim" => THUMBS.first(1), "digital_asset_download_paths_ssim" => LARGE.first(1)
    },
    "DAM assets all withheld" => { "digital_asset_metadata_ssm" => [ { "licence" => "None", "format" => "image", "tier" => "request" } ].map(&:to_json) },
    "audio, video and PDF" => { "licence_type_ssim" => [ "Public domain - Copyright expired" ],
                                "digital_media_ssim" => [ "audio|audio/mpeg|/digital-assets/media/GraingerLowRes.mp3|Interview", "video|video/mp4|/digital-assets/media/v.mp4|Film", "pdf|application/pdf|/d.pdf|Report" ] }
  }.freeze

  WIDTHS = { "desktop" => [ 1440, 900 ], "phone" => [ 390, 844 ] }.freeze
  SIZES = WIDTHS.merge("narrow" => [ 320, 800 ]).freeze

  teardown do
    RecordSolr.documents = nil
    page.current_window.resize_to(1440, 900)
  end

  def document(extra) = SolrDocument.new(BASE.merge("id" => "emu-9044").merge(extra)).tap { |doc| doc.instance_variable_set(:@response, Blacklight::Solr::Response.new({ "response" => { "docs" => [] } }, {})) }

  def open_record(extra, width)
    RecordSolr.documents = { "emu-9044" => document(extra) }
    page.current_window.resize_to(*SIZES.fetch(width))
    visit "/catalog/emu-9044"
    assert_selector "h1"
    assert_no_selector "html[aria-busy]"
  end

  VARIANTS.each do |name, extra|
    WIDTHS.each_key do |width|
      test "a #{name} record at #{width} width has no axe violations, one h1, ordered headings, no sideways scroll and only the media sticky" do
        open_record(extra, width)

        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ])
        assert_selector "h1", count: 1
        assert_selector ".record-split__details header.record-split__header h1"
        assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

        outline = page.evaluate_script("[...document.querySelectorAll('#main-container h1, #main-container h2, #main-container h3')].filter(e => e.getClientRects().length > 0).map(e => e.tagName + ' ' + e.textContent.trim())")
        # the media comes first in this layout, so its (visually hidden) "Digital assets" h2 may precede the title
        before_title = outline.take_while { |heading| !heading.start_with?("H1") }
        assert before_title.all? { |heading| heading.match?(/\AH2 Digital assets?\z/) }, outline.inspect
        levels = outline.drop(before_title.size).map { |heading| heading[1].to_i }
        assert levels.each_cons(2).all? { |a, b| b <= a + 1 }, "headings skip a level: #{outline.inspect}"
        assert_includes outline, "H2 Object details"
        assert_includes outline, "H2 Copyright and reuse"

        # The media column stays in view beside the scrolling details on a wide screen (the approved design); nothing else is sticky
        sticky = page.evaluate_script("[...document.querySelectorAll('#main-container *')].filter(e => e.getClientRects().length > 0 && ['sticky', 'fixed'].includes(getComputedStyle(e).position)).map(e => e.className)")
        # sticky exactly when it fits the window under the search strip (media_viewer_controller.js); a taller column scrolls
        fits = page.evaluate_script("(() => { const v = document.querySelector('.record-split__viewer'); return v.scrollHeight <= window.innerHeight - 60 && window.innerWidth >= 1024 && !!v.querySelector('.digital-assets') })()")
        assert_equal(fits ? [ "record-split__viewer is-sticky" ] : [], sticky)

        small = page.evaluate_script(<<~JS)
          [...document.querySelectorAll('.record-actions button, .record-actions a, .digital-assets__controls-row button, .digital-assets__controls-row a, .digital-assets__strip button, .digital-assets__thumb, .result-stepper a, .record-term')]
            .filter(e => e.getClientRects().length > 0).map(e => e.getBoundingClientRect()).filter(r => r.height < 24 || r.width < 24).length
        JS
        assert_equal 0, small, "a control is smaller than 24px"
      end
    end
  end

  test "at 320px every variant fits without scrolling sideways, long Collection ID and all" do
    VARIANTS.each_value do |extra|
      open_record(extra.merge("title_tsim" => [ "A very long title with Supercalifragilisticexpialidocious-and-more words" ]), "narrow")
      assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
    end
  end

  test "an imageless record starts at its header: the plain sentence, no media box, and a request link where the collection takes questions" do
    open_record({}, "desktop")

    assert_selector ".no-image", text: "No image of this record is available online."
    assert_no_selector ".digital-assets"
    assert_selector ".no-image a[target=_blank]"
    assert_equal "H1", page.evaluate_script("document.querySelector('#main-container h1, #main-container header h1').tagName")
  end

  test "the media sits on the page's white, whole, with no dark band and no minimum height; dark only in full screen" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")

    background = page.evaluate_script("getComputedStyle(document.querySelector('.digital-assets')).backgroundColor")
    assert_includes [ "rgba(0, 0, 0, 0)", "rgb(255, 255, 255)" ], background
    assert_equal "0px", page.evaluate_script("getComputedStyle(document.querySelector('.digital-assets__stage')).minHeight")
    image = page.evaluate_script("(() => { const i = document.querySelector('.digital-assets__image'); return [i.clientHeight, window.innerHeight, getComputedStyle(i).objectFit] })()")
    assert_operator image[0], :<=, image[1] * 0.71
    assert_equal "contain", image[2]
  end

  test "an open record's controls row has the access chip, the licence, named round tools and the one Download; a view-only record has no download link anywhere" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector ".digital-assets__controls-row .viewer-chip--open", text: "Open: view and download"
    assert_selector ".digital-assets__controls-row a.viewer-control[download]", text: "Download image"
    assert_selector ".digital-assets__controls-row button.viewer-control", text: "Zoom in"
    assert_selector "details#media-details summary", text: "Media details"

    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    assert_selector ".record-actions .access-notice--view-only"
    assert_no_selector "a[download]"
    assert_no_selector ".digital-assets a[href*='/digital-assets/']"
  end

  WIDTHS.each_key do |width|
    test "a record with one licensed and one unlicensed image at #{width} width shows the licensed one, says the other is withheld, and offers the download" do
      open_record(VARIANTS.fetch("per-asset licences, one shown and one withheld"), width)

      assert_selector ".digital-assets__main img[src^='#{LARGE.first}']"
      assert_selector ".digital-assets .access-notice--partly-withheld", text: "1 other digital asset of this record is not shown here"
      assert_selector ".access-notice--partly-withheld a[href='/access_requests/new?document_id=emu-9044']", text: "Request access to it"
      assert_selector ".digital-assets__controls-row a.viewer-control[download]", text: "Download image"
      assert_selector ".viewer-chip", text: "CC BY"
      notice = page.evaluate_script("(() => { const r = document.querySelector('.access-notice--partly-withheld').getBoundingClientRect(); return [r.left >= 0, r.right <= window.innerWidth] })()")
      assert_equal [ true, true ], notice, "the notice fits the width"
    end
  end

  test "a record whose DAM assets are all withheld has the request notice and no image" do
    open_record(VARIANTS.fetch("DAM assets all withheld"), "desktop")

    assert_selector ".digital-assets .access-notice--request", text: "This item is available on request"
    assert_no_selector ".digital-assets img, .access-notice--partly-withheld"
  end

  test "a request-only or sensitive record has no asset address in its page" do
    %w[request-only sensitive].each do |name|
      open_record(VARIANTS.fetch(name), "desktop")
      assert_no_selector ".record-split img[src*='/digital-assets/']"
      layout = page.evaluate_script("document.querySelector('.record-split').outerHTML")
      assert_not_includes layout, "/digital-assets/"
    end
  end

  test "from 1024px the media is on the left and the record's column on the right, the media staying in view as the column scrolls; below it, one column, media first" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    rect = ->(selector) { page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    viewer, details = rect.call(".record-split__viewer"), rect.call(".record-split__details")
    assert_operator details["left"], :>=, viewer["right"] - 1
    assert_in_delta viewer["top"], details["top"], 1
    page.execute_script("window.scrollTo(0, 600)")
    assert_in_delta 0, rect.call(".record-split__viewer")["top"], 1, "the media stays in view"

    open_record(VARIANTS.fetch("one image, open"), "phone")
    viewer, details = rect.call(".record-split__viewer"), rect.call(".record-split__details")
    assert_operator details["top"], :>=, viewer["bottom"] - 1
  end

  test "Copyright and reuse folds open to state the record's rights, on a phone and a desktop" do
    %w[phone desktop].each do |width|
      open_record({}, width)
      find("details#copyright-and-reuse summary", text: "Copyright and reuse").click
      assert_selector "details#copyright-and-reuse[open]", text: "Rights held by the University"
      assert_selector "details#copyright-and-reuse[open] a[href='/help#copyright']", text: "About copyright and terms of use"
    end
  end

  test "the Tab key moves through the record page in the order it reads, and each stop shows a focus ring" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    # start on the last control before the media (it comes first in this layout, then the record's column)
    page.evaluate_script(<<~JS)
      (() => { const all = [...document.querySelectorAll('a[href], button, input, select, summary, [tabindex]:not([tabindex="-1"])')].filter(e => e.getClientRects().length > 0 && !e.disabled),
                     first = all.findIndex(e => e.closest('.record-split__viewer')); all[first - 1].focus() })()
    JS

    stops = 16.times.map do
      page.driver.browser.keyboard.type(:Tab)
      page.evaluate_script(<<~JS)
        (() => { const e = document.activeElement, t = e.type === 'checkbox' ? e.closest('label') : e, s = getComputedStyle(t); return { text: (e.textContent || e.value || '').trim().replace(/\\s+/g, ' ').slice(0, 30), ring: s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) >= 2 } })()
      JS
    end
    texts = stops.map { |stop| stop["text"] }

    assert stops.all? { |stop| stop["ring"] }, stops.reject { |stop| stop["ring"] }.inspect
    # the media's round tools, then the record's column (its collection, then Save), in that order
    order = [ "Zoom in", "Zoom out", "Full screen", "Download image", "University Art Collection", "Save" ].map { |label| texts.index { |text| text.include?(label) } }
    assert_equal order.compact.sort, order.compact, texts.inspect
    assert_operator order.compact.size, :>=, 4, texts.inspect
  end

  test "Zoom in opens the viewer over the picture without moving anything; it follows the thumbnails, and zooming back out closes it" do
    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    rect = ->(selector) { page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    # where the controls row sits in the media column (the page may scroll to the button)
    row_offset = -> { page.evaluate_script("document.querySelector('.digital-assets__controls-row').getBoundingClientRect().top - document.querySelector('.record-split__viewer').getBoundingClientRect().top") }
    row = row_offset.call

    click_button "Zoom in"
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10 # the viewer's script loads on first use
    canvas = rect.call(".deep-zoom__stage .openseadragon-canvas")
    assert_operator canvas["width"], :>, 100
    assert_in_delta row, row_offset.call, 1, "the controls row did not move"

    find(".digital-assets__thumb:not([aria-current])", match: :first).click
    assert_selector ".digital-assets__thumb[aria-current=true][aria-label='Show image 2 of #{THUMBS.size}']"
    assert_match(/image 2 of/, page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').getAttribute('aria-label')"))
    assert_operator rect.call(".deep-zoom__stage .openseadragon-canvas")["width"], :>, 100, "the viewer keeps its size on another image"

    6.times do
      break unless page.has_selector?(".deep-zoom__stage", visible: true, wait: 0)

      click_button "Zoom out"
      sleep 0.4
    end
    assert_no_selector ".deep-zoom__stage", visible: true
    assert_selector ".digital-assets__image", visible: true
  end

  test "a long description is collapsed with Show more, and Show less collapses it again, its paragraphs kept" do
    open_record({ "description_tsim" => [ "#{'A cabinet of drawers. ' * 30}\n\nMade for the specimen collection." ] }, "desktop")

    toggle = find(".record-split__description button[aria-controls=record-description]")
    assert_equal [ "false", "Show more" ], [ toggle["aria-expanded"], toggle.text ]
    assert_no_selector ".record-split__paragraph", text: "Made for the specimen collection."

    toggle.click
    assert_equal [ "true", "Show less" ], [ toggle["aria-expanded"], toggle.text ]
    assert_selector "p.record-split__paragraph", text: "Made for the specimen collection."

    toggle.click
    assert_equal "false", toggle["aria-expanded"]
    assert_no_selector ".record-split__paragraph", text: "Made for the specimen collection."
  end

  test "a short description has no Show more" do
    open_record({ "description_tsim" => [ "A cabinet." ] }, "desktop")

    assert_selector ".record-split__lead", text: "A cabinet."
    assert_no_selector ".record-split__description button", visible: true
  end
end
