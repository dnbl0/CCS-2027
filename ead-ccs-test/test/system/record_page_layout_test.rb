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

  test "the image sits whole on the stage's text/primary, the bar under it with its stroke/strong top border; the viewer is at most 720px tall" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")

    assert_equal "rgb(34, 34, 34)", page.evaluate_script("getComputedStyle(document.querySelector('.media-viewer__stage')).backgroundColor")
    assert_equal [ "rgb(101, 108, 139)", "1px" ], page.evaluate_script("(() => { const s = getComputedStyle(document.querySelector('.media-viewer__bar')); return [s.borderTopColor, s.borderTopWidth] })()")
    assert_operator page.evaluate_script("document.querySelector('.media-viewer__body').getBoundingClientRect().height"), :<=, 720
    image = page.evaluate_script("(() => { const i = document.querySelector('.digital-assets__image'); return [i.clientHeight, window.innerHeight, getComputedStyle(i).objectFit] })()")
    assert_operator image[0], :<=, image[1] * 0.71
    assert_equal "contain", image[2]
  end

  test "an open record's controls bar has the named controls and the one Download; a view-only record has no download link anywhere" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector ".media-viewer__caption .viewer-chip--open", text: "Open: view and download"
    assert_selector ".media-viewer__bar button.viewer-control[aria-label='Zoom in']"
    # CCS-67: Download shows the essential information (caption, licence) to copy, then downloads
    find(".media-viewer__bar button.viewer-control[aria-label^='Download image']").click
    assert_selector "dialog[open] h2", text: "Before you download"
    assert_selector "dialog[open] .digital-assets__essential dt", text: "Caption"
    assert_selector "dialog[open] a.btn[download]", text: "Download image"
    find("dialog[open] .modal-footer button", text: "Close").click
    assert_no_selector "dialog[open]"
    # CCS-422: ⋮ opens the media information over the left of the viewer at its full height; focus moves to its heading; Escape
    # closes it and focus returns to ⋮
    image_box = "(() => { const r = document.querySelector('.digital-assets__image').getBoundingClientRect(), v = document.querySelector('.media-viewer__body').getBoundingClientRect(); return [Math.round(r.left - v.left), Math.round(r.top - v.top), Math.round(r.width), Math.round(r.height)] })()"
    image_before = page.evaluate_script(image_box)
    find("button.viewer-control[aria-controls=media-information]").click
    assert_selector "#media-information h3", text: "Media information"
    assert_equal "true", find("button.viewer-control[aria-controls=media-information]")["aria-expanded"]
    assert_equal "media-information-heading", page.evaluate_script("document.activeElement.id")
    panel, body = %w[#media-information .media-viewer__body].map { |sel| page.evaluate_script("document.querySelector('#{sel}').getBoundingClientRect().toJSON()") }
    assert_in_delta body["height"], panel["height"], 1, "the panel is the viewer's full height"
    assert_equal 0, page.evaluate_script("document.getElementById('media-information').offsetLeft"), "the panel is on the left (its layout box: the slide-in is a transform)"
    assert_equal image_before, page.evaluate_script(image_box), "opening the panel does not move the image"
    assert page.evaluate_script("document.querySelector('[aria-controls=media-information]').inert"), "⋮ is under the panel, so it leaves the tab order"
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
      assert_selector ".media-viewer__bar button.viewer-control[aria-label^='Download image']"
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

  test "the record follows the Van Gogh Museum's layout: from 1024px the actions column on the left, the record on the right; on a phone the header, then the actions, then the sections" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    rect = ->(selector) { page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    head, aside, body = rect.call(".record-showcase__head"), rect.call(".record-showcase__aside"), rect.call(".record-showcase__body")
    assert_operator aside["right"], :<=, head["left"] + 1, "the actions column is left of the record"
    assert_operator body["top"], :>=, head["bottom"] - 1
    assert_equal "rgb(244, 244, 244)", page.evaluate_script("getComputedStyle(document.querySelector('.record--showcase')).backgroundColor"), "the record sits on the page's grey"

    open_record(VARIANTS.fetch("one image, open"), "phone")
    head, aside, body = rect.call(".record-showcase__head"), rect.call(".record-showcase__aside"), rect.call(".record-showcase__body")
    assert_operator aside["top"], :>=, head["bottom"] - 1
    assert_operator body["top"], :>=, aside["bottom"] - 1
  end

  test "under the title: the status, the bold maker line and the facts; the folding sections start closed, and the rights link opens Rights and reuse" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector ".record-showcase__status svg[aria-hidden=true]"
    assert_selector ".record-showcase__status", text: "You can view the image online"
    assert_selector ".record-showcase__facts", text: "accession number"
    %w[object-details rights-and-reuse how-to-cite about-this-record].each { |id| assert_equal false, page.evaluate_script("document.getElementById('#{id}').open"), id }
    assert_selector "#use-and-access h2", text: "Use and access"

    find("#use-and-access a", text: "All rights and contact details").click
    assert_selector "#rights-and-reuse[open]", text: "Rights held by the University"
    assert_selector "#rights-and-reuse a[href='/help#copyright']", text: "About copyright and terms of use"
    assert_equal "SUMMARY", page.evaluate_script("document.activeElement.tagName")

    find("#object-details summary").click
    assert_selector "#object-details[open] .record-facts__row dt", text: /object type/i
    assert_selector "#object-details[open] [data-testid=record-identifier]"
    assert_selector ".record-search .record-search__term", minimum: 1
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
        (() => { const e = document.activeElement, t = e.type === 'checkbox' ? e.closest('label') : e, s = getComputedStyle(t); return { text: (e.getAttribute('aria-label') || e.textContent || e.value || '').trim().replace(/\\s+/g, ' ').slice(0, 30), ring: s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) >= 2 } })()
      JS
    end
    texts = stops.map { |stop| stop["text"] }

    assert stops.all? { |stop| stop["ring"] }, stops.reject { |stop| stop["ring"] }.inspect
    # the controls bar left to right (⋮, rotate, zoom, full screen, Download), then the record's column (Save), in that order
    order = [ "Media information", "Rotate left", "Zoom in", "Reset zoom", "Zoom out", "Full screen", "Download image", "Save" ].map { |label| texts.index { |text| text.include?(label) } }
    assert_equal order.compact.sort, order.compact, texts.inspect
    assert_operator order.compact.size, :>=, 4, texts.inspect
  end

  test "Zoom in opens the viewer over the picture without moving anything; Reset and Zoom out follow the zoom; another thumbnail starts at the whole picture" do
    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    rect = ->(selector) { page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    bar = -> { page.evaluate_script("document.querySelector('.media-viewer__bar').getBoundingClientRect().top - document.querySelector('.media-viewer__body').getBoundingClientRect().top") }
    before = bar.call
    control = ->(name) { find(".media-viewer__bar button[aria-label='#{name}']") }
    assert_equal "true", control.call("Reset zoom and rotation")["aria-disabled"]

    control.call("Zoom in").click
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10 # the viewer's script loads on first use
    assert_operator rect.call(".deep-zoom__stage .openseadragon-canvas")["width"], :>, 100
    assert_in_delta before, bar.call, 1, "the controls bar did not move"
    assert_nil control.call("Reset zoom and rotation")["aria-disabled"]
    assert_selector ".media-viewer__readout", text: /\d+%/, wait: 5

    # Reset returns to the plain image at the whole picture
    control.call("Reset zoom and rotation").click
    assert_no_selector ".deep-zoom__stage", visible: true
    assert_equal "true", control.call("Reset zoom and rotation")["aria-disabled"]

    # another thumbnail starts whole and unrotated, and is announced
    control.call("Zoom in").click
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
    find(".digital-assets__thumb:not([aria-current])", match: :first).click
    assert_selector ".digital-assets__thumb[aria-current=true][aria-label='Show image 2 of #{THUMBS.size}']"
    assert_no_selector ".deep-zoom__stage", visible: true
    assert_selector "[data-media-viewer-target=status]", text: "Image 2 of #{THUMBS.size} shown", visible: :all
  end

  test "Rotate right turns the image and says so; Reset turns it back" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    find(".media-viewer__bar button[aria-label='Rotate right']").click
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
    assert_selector "[data-media-viewer-target=status]", text: "Rotated 90 degrees", visible: :all, wait: 5
    assert_nil find(".media-viewer__bar button[aria-label='Reset zoom and rotation']")["aria-disabled"]
    find(".media-viewer__bar button[aria-label='Reset zoom and rotation']").click
    assert_no_selector ".deep-zoom__stage", visible: true
  end

  test "Previous and Next stop at the ends; Hide thumbnails widens the stage, and the choice lasts for the visit" do
    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    page.execute_script("sessionStorage.removeItem('ccs-media-viewer-thumbnails')")
    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    previous, nxt = find("button[aria-label='Previous image']"), find("button[aria-label='Next image']")
    assert_equal "true", previous["aria-disabled"]
    # the one on show is unmistakable: a 4px navy frame inside the picture and a solid navy number (the others have neither)
    frame = ->(selector) { page.evaluate_script("(() => { const t = document.querySelector(\"#{selector}\"); return [getComputedStyle(t, '::after').boxShadow, getComputedStyle(t.querySelector('.digital-assets__thumb-number')).backgroundColor] })()") }
    current, other = frame.call(".digital-assets__thumb[aria-current=true]"), frame.call(".digital-assets__thumb:not([aria-current])")
    assert_match(/4px/, current[0]); assert_equal "none", other[0]
    assert_not_equal current[1], other[1]
    (THUMBS.size - 1).times { nxt.click }
    assert_equal "true", nxt["aria-disabled"]
    assert_nil previous["aria-disabled"]
    page.send_keys(:home) # arrow keys, Home and End move between thumbnails when one has focus
    width = page.evaluate_script("document.querySelector('.media-viewer__stage').getBoundingClientRect().width")

    find("button[aria-label='Hide thumbnails']").click
    assert_no_selector "#media-thumbnails"
    assert_equal "Show thumbnails", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    assert_operator page.evaluate_script("document.querySelector('.media-viewer__stage').getBoundingClientRect().width"), :>, width
    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    assert_no_selector "#media-thumbnails"
    find("button[aria-label='Show thumbnails']").click
    assert_selector "#media-thumbnails .digital-assets__thumb", count: THUMBS.size
  end

  test "with the media information open, the viewer has no axe violations, on a phone (covering the stage) and a desktop" do
    %w[phone desktop].each do |width|
      open_record(VARIANTS.fetch("several images, view-only"), width)
      find("button[aria-label='Media information']").click
      assert_selector "#media-information"
      assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ])
      find("#media-information button[aria-label='Close media information']").click
    end
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
