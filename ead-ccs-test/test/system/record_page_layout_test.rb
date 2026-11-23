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
        assert_selector ".record__header .record__identity h1"
        assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

        outline = page.evaluate_script("[...document.querySelectorAll('#main-container h1, #main-container h2, #main-container h3')].filter(e => e.getClientRects().length > 0).map(e => e.tagName + ' ' + e.textContent.trim())")
        # the title comes first (any content warning above it is an h2 of its own)
        before_title = outline.take_while { |heading| !heading.start_with?("H1") }
        levels = outline.drop(before_title.size).map { |heading| heading[1].to_i }
        assert levels.each_cons(2).all? { |a, b| b <= a + 1 }, "headings skip a level: #{outline.inspect}"
        assert_includes outline, "H2 Object overview"
        assert_includes outline, "H2 Record details and notes"

        # Nothing else in the page sticks (the search strip is the header's)
        sticky = page.evaluate_script("[...document.querySelectorAll('#main-container *')].filter(e => e.getClientRects().length > 0 && ['sticky', 'fixed'].includes(getComputedStyle(e).position)).map(e => e.className)")
        assert_equal [], sticky.reject { |name| name.include?("record__media") } # the media stays in view on desktop

        small = page.evaluate_script(<<~JS)
          [...document.querySelectorAll('.record-actions button, .record-actions a, .media-viewer__controls button, .media-viewer__licence a, .digital-assets__thumb, .record__name, .record-more__tab, .result-stepper a, .record-term')]
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

  test "the image sits whole on the grey panel in the header's right column, never taller than the window allows" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")

    panel = page.evaluate_script("getComputedStyle(document.querySelector('.media-viewer__panel')).backgroundColor")
    assert_not_equal [ "rgba(0, 0, 0, 0)", "rgb(255, 255, 255)" ].include?(panel), true, "the panel is grey"
    identity, media = %w[.record__identity .record__media].map { |sel| page.evaluate_script("document.querySelector('#{sel}').getBoundingClientRect().toJSON()") }
    assert_operator media["left"], :>=, identity["right"] - 1, "the media is right of the title"
    image = page.evaluate_script("(() => { const i = document.querySelector('.digital-assets__image'); return [i.clientHeight, window.innerHeight, getComputedStyle(i).objectFit] })()")
    assert_operator image[0], :<=, image[1] * 0.71
    assert_equal "contain", image[2]
  end

  test "an open record's panel has round Zoom and Download and Media information; a view-only record has no download link anywhere" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector ".media-viewer__licence", text: "You can download the image."
    assert_selector ".media-viewer__controls button.media-viewer__tool[aria-label='Zoom into the image']"
    # CCS-67: Download shows the essential information (caption, licence) to copy, then downloads
    find(".media-viewer__controls button.media-viewer__tool[aria-label^='Download image']").click
    assert_selector "dialog[open] h2", text: "Download this image"
    assert_selector "dialog[open] .digital-assets__essential dt", text: "Caption"
    assert_selector "dialog[open] a.btn[download]", text: "Download image"
    find("dialog[open] .modal-footer button", text: "Cancel").click
    assert_no_selector "dialog[open]"
    # CCS-422: Media information opens a drawer from the right; Escape closes it and focus returns to the button
    find("button.media-viewer__info-button").click
    assert_selector "dialog#media-information[open] h2", text: "Media information"
    page.evaluate_async_script("const done = arguments[0]; Promise.all(document.getElementById('media-information').getAnimations().map((a) => a.finished)).then(() => done())")
    drawer = page.evaluate_script("document.getElementById('media-information').getBoundingClientRect().toJSON()")
    assert_in_delta page.evaluate_script("window.innerWidth"), drawer["right"], 1, "the drawer is on the right"
    assert_in_delta page.evaluate_script("window.innerHeight"), drawer["height"], 1, "the drawer is the window's full height"
    page.send_keys(:escape)
    assert_no_selector "dialog#media-information[open]"
    assert page.evaluate_script("document.activeElement.classList.contains('media-viewer__info-button')")

    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    assert_selector ".media-viewer__licence", text: "Download is not available"
    assert_selector ".media-viewer__licence a[href='/access_requests/new?document_id=emu-9044']", text: "Request to use this image"
    assert_no_selector "a[download]", visible: :all
    assert_no_selector ".digital-assets a[href*='/digital-assets/']"
  end

  WIDTHS.each_key do |width|
    test "a record with one licensed and one unlicensed image at #{width} width shows the licensed one, says the other is withheld, and offers the download" do
      open_record(VARIANTS.fetch("per-asset licences, one shown and one withheld"), width)

      assert_selector ".digital-assets__main img[src^='#{LARGE.first}']"
      assert_selector ".digital-assets .access-notice--partly-withheld", text: "1 other digital asset of this record is not shown here"
      assert_selector ".access-notice--partly-withheld a[href='/access_requests/new?document_id=emu-9044']", text: "Request access to it"
      assert_selector ".media-viewer__controls button.media-viewer__tool[aria-label^='Download image']"
      assert_selector ".media-viewer__licence", text: "CC BY."
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
      assert_no_selector ".record img[src*='/digital-assets/']"
      layout = page.evaluate_script("document.querySelector('.record').outerHTML")
      assert_not_includes layout, "/digital-assets/"
    end
  end

  test "the record's layout: the title left and the media right, then sections with their heading on the left" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    rect = ->(selector) { page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    identity, media = rect.call(".record__identity"), rect.call(".record__media")
    assert_operator media["left"], :>=, identity["right"] - 1, "the media is right of the title and names"
    heading, facts = rect.call("#record-overview-heading"), rect.call(".record__facts")
    assert_operator facts["left"], :>, heading["right"], "the facts are right of their heading"
    assert_equal "rgb(255, 255, 255)", page.evaluate_script("getComputedStyle(document.querySelector('.record')).backgroundColor")

    # a phone: the title and date, then the media, then the names
    open_record(VARIANTS.fetch("one image, open"), "phone")
    title, media, names = rect.call(".record__title"), rect.call(".record__media"), rect.call(".record__names")
    assert_operator media["top"], :>=, title["bottom"]
    assert_operator names["top"], :>=, media["bottom"]
    assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
  end

  test "the header: associated names and the collection; the licence line opens Use and access; the details and notes start closed" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector "#record-names-heading", text: "Associated names"
    assert_selector "#record-overview-heading", text: "Object overview"
    assert_selector ".record__fact dt", text: "Accession Number"
    %w[object-details record-use how-to-cite about-this-record].each { |id| assert_equal false, page.evaluate_script("document.getElementById('#{id}').open"), id }

    find(".media-viewer__licence a", text: "Use and access").click
    assert_selector "#record-use[open]", text: "Rights held by the University"
    assert_selector "#record-use a[href='/help#copyright']", text: "About copyright and terms of use"

    find("#object-details summary").click
    assert_selector "#object-details[open] .record-facts__row dt", text: /object type/i
    assert_selector "#object-details[open] [data-testid=record-identifier]"
  end

  test "the Tab key moves through the header in the order it reads, and each stop shows a focus ring" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    page.execute_script("document.querySelector('.record__title').setAttribute('tabindex', '-1'); document.querySelector('.record__title').focus()") # start on the title

    stops = 14.times.map do
      page.driver.browser.keyboard.type(:Tab)
      page.evaluate_script(<<~JS)
        (() => { const e = document.activeElement, t = e.type === 'checkbox' ? e.closest('label') : e, s = getComputedStyle(t); return { text: (e.getAttribute('aria-label') || t.textContent || e.value || '').trim().replace(/\s+/g, ' ').slice(0, 30), ring: s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) >= 2 } })()
      JS
    end
    texts = stops.map { |stop| stop["text"] }

    assert stops.all? { |stop| stop["ring"] }, stops.reject { |stop| stop["ring"] }.inspect
    # the title's column (the collection, Save, a name), then the media (Zoom, Download, Media information, Use and access)
    order = [ "See more from this collection", "Save", "Grimwade", "Zoom into the image", "Download image", "Media information", "Use and access" ].map { |label| texts.index { |text| text.include?(label) } }
    assert_equal order.compact.sort, order.compact, texts.inspect
    assert_operator order.compact.size, :>=, 6, texts.inspect
  end

  test "Zoom opens the image full screen in a modal; the tools follow the zoom; Next shows the next image; Escape closes and returns focus" do
    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    zoom = find(".media-viewer__controls button[aria-label='Zoom into the image']")
    zoom.click
    assert_selector "dialog.media-zoom[open]"
    assert_selector ".media-zoom .deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10 # the viewer's script loads on first use
    dialog = page.evaluate_script("document.querySelector('dialog.media-zoom').getBoundingClientRect().toJSON()")
    assert_in_delta page.evaluate_script("window.innerWidth"), dialog["width"], 1, "the modal fills the window"
    control = ->(name) { find("dialog.media-zoom button[aria-label='#{name}']") }
    assert_equal "true", control.call("Reset zoom and rotation")["aria-disabled"]
    assert_equal "true", control.call("Previous image")["aria-disabled"]

    control.call("Zoom in").click
    assert_selector ".media-zoom__readout", text: /\d+%/, wait: 5
    assert_nil control.call("Reset zoom and rotation")["aria-disabled"]
    control.call("Reset zoom and rotation").click
    assert_equal "true", control.call("Reset zoom and rotation")["aria-disabled"]

    control.call("Next image").click
    assert_selector ".digital-assets__thumb[aria-current=true][aria-label='Show image 2 of #{THUMBS.size}']", visible: :all
    assert_selector "[data-media-viewer-target=status]", text: "Image 2 of #{THUMBS.size} shown", visible: :all
    assert_equal "Next image", page.evaluate_script("document.activeElement.getAttribute('aria-label')"), "Next keeps focus"

    page.send_keys(:escape)
    assert_no_selector "dialog.media-zoom[open]"
    assert_equal "Zoom into the image", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
  end

  test "Rotate turns the image and says so; Reset turns it back" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    find(".media-viewer__controls button[aria-label='Zoom into the image']").click
    assert_selector ".media-zoom .deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
    find("dialog.media-zoom button[aria-label='Rotate']").click
    assert_selector "[data-media-viewer-target=status]", text: "Rotated 90 degrees", visible: :all, wait: 5
    reset = find("dialog.media-zoom button[aria-label='Reset zoom and rotation']")
    assert_nil reset["aria-disabled"]
    reset.click
    assert_equal "true", reset["aria-disabled"]
    find("dialog.media-zoom button[aria-label='Close zoom']").click
    assert_no_selector "dialog.media-zoom[open]"
  end

  test "a thumbnail shows its image on the panel, the one on show framed; arrow keys move between thumbnails" do
    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    frame = ->(selector) { page.evaluate_script("getComputedStyle(document.querySelector(\"#{selector}\"), '::after').borderTopColor") }
    assert_not_equal frame.call(".digital-assets__thumb[aria-current=true]"), frame.call(".digital-assets__thumb:not([aria-current])")
    find(".digital-assets__thumb[aria-label='Show image 2 of #{THUMBS.size}']").click
    assert_selector ".digital-assets__thumb[aria-current=true][aria-label='Show image 2 of #{THUMBS.size}']"
    page.send_keys(:end)
    assert_equal "Show image #{THUMBS.size} of #{THUMBS.size}", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    page.send_keys(:home)
    assert_equal "Show image 1 of #{THUMBS.size}", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
  end

  test "with the zoom modal or the media information open, the page has no axe violations, on a phone and a desktop" do
    %w[phone desktop].each do |width|
      open_record(VARIANTS.fetch("several images, view-only"), width)
      find("button.media-viewer__info-button").click
      assert_selector "dialog#media-information[open]"
      assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ])
      find("#media-information button[aria-label='Close media information']").click
      find(".media-viewer__controls button[aria-label='Zoom into the image']").click
      assert_selector ".media-zoom .deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
      assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ])
      # The zoom's title and position, and Next moving the position on
      assert_selector ".media-zoom .media-zoom__title", text: BASE["title_tsim"].first
      assert_selector ".media-zoom .media-zoom__position", text: "Image 1 of #{THUMBS.size}"
      find(".media-zoom button[aria-label='Next image']").click
      assert_selector ".media-zoom .media-zoom__position", text: "Image 2 of #{THUMBS.size}"
      page.send_keys(:escape)
      assert_selector ".media-viewer__counter", text: "Image 2 of #{THUMBS.size}"
    end
  end

  test "an open accordion item keeps its content clear of its title: 24px inside the panel, on the pale grey, at every width" do
    %w[desktop narrow].each do |width|
      open_record(VARIANTS.fetch("several images, view-only"), width)
      page.execute_script("document.getElementById('record-use').open = true")
      gaps = page.evaluate_script(<<~JS)
        (() => { const item = document.getElementById("record-use"), summary = item.querySelector("summary"), panel = item.querySelector(".record-accordion__panel");
                 const first = panel.firstElementChild, style = getComputedStyle(panel);
                 return [Math.round(first.getBoundingClientRect().top - summary.getBoundingClientRect().bottom), parseFloat(style.paddingLeft), style.backgroundColor] })()
      JS
      assert_operator gaps[0], :>=, 24, "#{width}: #{gaps.inspect}"
      assert_operator gaps[1], :>=, 24, "#{width}: #{gaps.inspect}"
      assert_equal "rgb(248, 248, 248)", gaps[2]
    end
  end

  test "the panel's tools sit on a toolbar joined to the panel (a rule above them), one style, no IIIF button" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    bar = page.evaluate_script(<<~JS)
      (() => { const bar = document.querySelector(".media-viewer__controls"), panel = bar.closest(".media-viewer__panel"); const s = getComputedStyle(bar);
               return [s.borderTopWidth, s.backgroundColor, Math.round(panel.getBoundingClientRect().bottom - bar.getBoundingClientRect().bottom),
                       [...bar.querySelectorAll("button")].filter(b => b.offsetParent).map(b => getComputedStyle(b).boxShadow)] })()
    JS
    assert_equal "1px", bar[0]
    assert_equal "rgb(255, 255, 255)", bar[1]
    assert_operator bar[2], :<=, 1, "the bar is the panel's foot"
    assert bar[3].all? { |shadow| shadow == "none" }, bar.inspect
    assert_no_text "Use with IIIF"
  end

  test "a long description fades out above Read more, and Read less collapses it again, its paragraphs kept" do
    open_record({ "description_tsim" => [ "#{'A cabinet of drawers. ' * 30}\n\nMade for the specimen collection." ] }, "desktop")

    assert_selector "#record-about-object-heading", text: "About this object"
    toggle = find(".record__description button[aria-controls=record-description]")
    assert_equal [ "false", "Read more" ], [ toggle["aria-expanded"], toggle.text ]
    assert_no_selector ".record__description-text p", text: "Made for the specimen collection."
    # CCS-413: the first 2 lines while collapsed (CCS-532)
    lines = page.evaluate_script("(() => { const p = document.querySelector('.record__lead'); return Math.round(p.clientHeight / parseFloat(getComputedStyle(p).lineHeight)) })()")
    assert_equal 2, lines

    toggle.click
    assert_equal [ "true", "Read less" ], [ toggle["aria-expanded"], toggle.text ]
    assert_selector ".record__description-text p", text: "Made for the specimen collection."

    toggle.click
    assert_equal "false", toggle["aria-expanded"]
    assert_no_selector ".record__description-text p", text: "Made for the specimen collection."
  end

  test "a short description has no Read more" do
    open_record({ "description_tsim" => [ "A cabinet." ] }, "desktop")

    assert_selector ".record__lead", text: "A cabinet."
    assert_no_selector ".record__description button", visible: true
  end

  test "You may be interested in: tabs (the arrow keys move between them), each panel's cards loading once it is shown" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    page.execute_script("document.getElementById('more-from-the-collections').scrollIntoView({ behavior: 'instant' })")
    assert_selector "#record-more-heading", text: "You may be interested in"
    tabs = page.all("[role=tab]")
    assert_equal "Similar", tabs.first.text
    assert_operator tabs.size, :>, 1
    assert_selector "#more-row-similar", visible: true # the first tab's panel shows
    tabs.first.click
    page.send_keys(:right)
    assert_equal "true", tabs[1]["aria-selected"]
    assert_equal tabs[1]["id"], page.evaluate_script("document.activeElement.id")
    assert_selector "##{tabs[1]['aria-controls']}", visible: true
    assert_no_selector "#more-row-similar", visible: true
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ])
  end

  # --- Figma Record/Actions, option A: Save, Share, then More (a menu button)
  test "More is a menu button: Enter opens it on the first item, Up wraps to the last, Escape closes it and returns focus" do
    open_record(VARIANTS["one image, open"], "desktop")
    page.execute_script("document.querySelector('.more-actions__button').focus()")
    page.driver.browser.keyboard.type(:Enter)
    assert_selector ".more-actions__button[aria-expanded=true]"
    assert_selector "li:first-child > .more-actions__item:focus", text: "Add to list"
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ])

    page.driver.browser.keyboard.type(:Up)
    assert_selector ".more-actions__item:focus", text: "Cite this record" # Up from the first wraps to the last

    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector ".more-actions__menu"
    assert_selector ".more-actions__button[aria-expanded=false]"
    assert_selector ".more-actions__button:focus" # Escape returns focus to More
  end

  test "Cite this record and Add to list in More's menu open their dialogs (one width), and closing each returns focus to More" do
    open_record(VARIANTS["one image, open"], "desktop")
    find(".more-actions__button").click
    find("[role=menuitem]", text: "Cite this record").click
    assert_selector "dialog.cite__dialog[open]"
    assert_selector ".cite__style", count: 4
    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector "dialog.cite__dialog[open]"
    assert_selector ".more-actions__button:focus" # focus returns to More

    find(".more-actions__button").click
    find("[role=menuitem]", text: "Add to list").click
    assert_selector "dialog.list-dialog[open]"
    widths = page.evaluate_script("[...document.querySelectorAll('dialog.list-dialog .modal-content, dialog.cite__dialog .modal-content')].map(e => getComputedStyle(e.closest('.modal-dialog')).maxWidth)")
    assert_equal 1, widths.uniq.size, widths.inspect
    page.driver.browser.keyboard.type(:Escape)
    assert_no_selector "dialog.list-dialog[open]"
    assert_selector ".more-actions__button:focus"
  end

  test "on a 320px phone Save, Share and More keep to one line, every target at least 44px tall and inside the screen" do
    open_record(VARIANTS["one image, open"], "narrow")
    boxes = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".record-actions__row > *")).filter(el => el.getClientRects().length)
        .map(el => { const target = el.querySelector("label, button") || el; const r = target.getBoundingClientRect(); return [Math.round(r.top), Math.round(r.height), Math.round(r.right)] })
    JS
    assert_equal 3, boxes.size, boxes.inspect
    assert_equal 1, boxes.map(&:first).uniq.size, boxes.inspect
    assert boxes.all? { |_top, height, right| height >= 44 && right <= 304 }, boxes.inspect # inside the 16px gutter
  end
end
