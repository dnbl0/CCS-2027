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
        assert_selector ".record-showcase__card header.record-showcase__header h1"
        assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

        outline = page.evaluate_script("[...document.querySelectorAll('#main-container h1, #main-container h2, #main-container h3')].filter(e => e.getClientRects().length > 0).map(e => e.tagName + ' ' + e.textContent.trim())")
        # the media comes first in this layout, so its (visually hidden) "Digital assets" h2 may precede the title
        before_title = outline.take_while { |heading| !heading.start_with?("H1") }
        assert before_title.all? { |heading| heading.match?(/\AH2 Digital assets?\z/) }, outline.inspect
        levels = outline.drop(before_title.size).map { |heading| heading[1].to_i }
        assert levels.each_cons(2).all? { |a, b| b <= a + 1 }, "headings skip a level: #{outline.inspect}"
        assert_includes outline, "H2 Object details"
        assert_includes outline, "H2 Use and access"

        # Nothing in the page sticks (the showcase layout scrolls as one page; the search strip is the header's)
        sticky = page.evaluate_script("[...document.querySelectorAll('#main-container *')].filter(e => e.getClientRects().length > 0 && ['sticky', 'fixed'].includes(getComputedStyle(e).position)).map(e => e.className)")
        assert_equal [], sticky

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
    assert_selector ".digital-assets__controls-row button.viewer-control", text: "Zoom in"
    # CCS-67: Download shows the essential information (caption, licence) to copy, then downloads
    find(".digital-assets__controls-row button.viewer-control", text: "Download image").click
    assert_selector "dialog[open] h2", text: "Before you download"
    assert_selector "dialog[open] .digital-assets__essential dt", text: "Caption"
    assert_selector "dialog[open] a.btn[download]", text: "Download image"
    find("dialog[open] .modal-footer button", text: "Close").click
    assert_no_selector "dialog[open]"
    # CCS-422: the i tool opens the media information over the image; Escape closes it and focus returns to the tool
    find("button.viewer-control[aria-controls=media-information]").click
    assert_selector "#media-information h3", text: "Media information"
    assert_equal "true", find("button.viewer-control[aria-controls=media-information]")["aria-expanded"]
    page.send_keys(:escape)
    assert_no_selector "#media-information"
    assert page.evaluate_script("document.activeElement.getAttribute('aria-controls') === 'media-information'")

    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    assert_selector "#use-and-access", text: "Download is not available"
    assert_selector "#use-and-access a[href='/access_requests/new?document_id=emu-9044']", text: "Request to use this image"
    assert_no_selector "a[download]", visible: :all
    assert_no_selector ".digital-assets a[href*='/digital-assets/']"
  end

  WIDTHS.each_key do |width|
    test "a record with one licensed and one unlicensed image at #{width} width shows the licensed one, says the other is withheld, and offers the download" do
      open_record(VARIANTS.fetch("per-asset licences, one shown and one withheld"), width)

      assert_selector ".digital-assets__main img[src^='#{LARGE.first}']"
      assert_selector ".digital-assets .access-notice--partly-withheld", text: "1 other digital asset of this record is not shown here"
      assert_selector ".access-notice--partly-withheld a[href='/access_requests/new?document_id=emu-9044']", text: "Request access to it"
      assert_selector ".digital-assets__controls-row button.viewer-control", text: "Download image"
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
      assert_no_selector ".record--showcase img[src*='/digital-assets/']"
      layout = page.evaluate_script("document.querySelector('.record--showcase').outerHTML")
      assert_not_includes layout, "/digital-assets/"
    end
  end

  test "the image is centred on its band and the card overlaps the band's foot; from 1024px the actions sit beside the record, on a phone between its header and Object details" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    rect = ->(selector) { page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    hero, card, image = rect.call(".record-showcase__hero"), rect.call(".record-showcase__card"), rect.call(".digital-assets__main")
    assert_operator card["top"], :<, hero["bottom"], "the card overlaps the band"
    assert_in_delta (hero["left"] + hero["right"]) / 2, (image["left"] + image["right"]) / 2, 2, "the image is centred"
    head, aside, body = rect.call(".record-showcase__head"), rect.call(".record-showcase__aside"), rect.call(".record-showcase__body")
    assert_operator aside["left"], :>=, head["right"] - 1
    assert_operator body["top"], :>=, head["bottom"] - 1

    open_record(VARIANTS.fetch("one image, open"), "phone")
    head, aside, body = rect.call(".record-showcase__head"), rect.call(".record-showcase__aside"), rect.call(".record-showcase__body")
    assert_operator aside["top"], :>=, head["bottom"] - 1
    assert_operator body["top"], :>=, aside["bottom"] - 1
  end

  test "Use and access states the record's rights on a phone and a desktop; Object details is open on a desktop and closed on a phone" do
    { "phone" => false, "desktop" => true }.each do |width, open|
      open_record({}, width)
      assert_selector "#use-and-access h2", text: "Use and access"
      # the rights, terms and contact are one step away
      assert_no_selector "#use-and-access", text: "Rights held by the University"
      find("#use-and-access summary", text: "Rights, credit and contact").click
      assert_selector "#use-and-access", text: "Rights held by the University"
      assert_selector "#use-and-access a[href='/help#copyright']", text: "About copyright and terms of use"
      assert_equal open, page.evaluate_script("document.getElementById('object-details').open")
    end
    assert_selector "#object-details[open] .record-facts__row dt", text: /object type/i # letter-spaced capitals, set in CSS
    # the first rows, then the rest continue in place, in the sheet's order
    if page.has_selector?("#more-details summary", wait: 0)
      shown = page.all("#object-details .record-facts__row dt").size
      find("#more-details summary").click
      assert_operator page.all("#object-details .record-facts__row dt").size, :>, shown
      assert_selector "#more-details[open] [data-testid=record-identifier]"
    end
    # the key rows under the title: who made it, label beside value
    label, value = page.evaluate_script("(() => { const r = document.querySelector('.record-showcase__lead-rows .record-facts__row'); return [r.querySelector('dt').getBoundingClientRect().toJSON(), r.querySelector('dd').getBoundingClientRect().toJSON()] })()")
    assert_operator value["left"], :>, label["right"]
  end

  test "the Tab key moves through the record page in the order it reads, and each stop shows a focus ring" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    # start on the last control before the media (it comes first in this layout, then the record's column)
    page.evaluate_script(<<~JS)
      (() => { const all = [...document.querySelectorAll('a[href], button, input, select, summary, [tabindex]:not([tabindex="-1"])')].filter(e => e.getClientRects().length > 0 && !e.disabled),
                     first = all.findIndex(e => e.closest('.record-showcase__hero')); all[first - 1].focus() })()
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
    row_offset = -> { page.evaluate_script("document.querySelector('.digital-assets__controls-row').getBoundingClientRect().top - document.querySelector('.record-showcase__hero').getBoundingClientRect().top") }
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

  test "a long description fades out above Read more, and Read less collapses it again, its paragraphs kept" do
    open_record({ "description_tsim" => [ "#{'A cabinet of drawers. ' * 30}\n\nMade for the specimen collection." ] }, "desktop")

    toggle = find(".record-showcase__description button[aria-controls=record-description]")
    assert_equal [ "false", "Read more" ], [ toggle["aria-expanded"], toggle.text ]
    assert_no_selector ".record-showcase__description-text p", text: "Made for the specimen collection."
    # CCS-413: three lines while collapsed
    lines = page.evaluate_script("(() => { const p = document.querySelector('.record-showcase__lead'); return Math.round(p.clientHeight / parseFloat(getComputedStyle(p).lineHeight)) })()")
    assert_equal 3, lines

    toggle.click
    assert_equal [ "true", "Read less" ], [ toggle["aria-expanded"], toggle.text ]
    assert_selector ".record-showcase__description-text p", text: "Made for the specimen collection."

    toggle.click
    assert_equal "false", toggle["aria-expanded"]
    assert_no_selector ".record-showcase__description-text p", text: "Made for the specimen collection."
  end

  test "a short description has no Show more" do
    open_record({ "description_tsim" => [ "A cabinet." ] }, "desktop")

    assert_selector ".record-showcase__lead", text: "A cabinet."
    assert_no_selector ".record-showcase__description button", visible: true
  end

  test "You may also like lays six similar records' pictures on the grey band, and Shuffle shows others" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    page.execute_script("document.getElementById('similar-records').scrollIntoView({ behavior: 'instant' })")
    skip "the core holds no similar records with pictures for this record" unless page.has_selector?("#related-objects", wait: 8)

    assert_selector "#related-objects h2", text: "You may also like"
    assert_operator page.all(".record-also__item", visible: true).size, :<=, 6
    page.all(".record-also__print", visible: true).each { |link| assert link.text.strip.present?, "every picture is a link named by its title" }
    if page.all(".record-also__item", visible: :all).size > 6
      before = page.all(".record-also__item", visible: true).map(&:text)
      click_button "Shuffle objects"
      assert_selector "[data-shuffle-target=status]", text: "Showing other objects", visible: :all
      assert_not_equal before, page.all(".record-also__item", visible: true).map(&:text)
    end
  end
end
