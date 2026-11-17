require "application_system_test_case"
require_relative "../support/stub_records"

# The record page's layout in every variant a record can be in, at a desktop and a phone width: axe (WCAG 2.2 AA rules too), no
# sideways scroll, one h1, the headings in order, nothing sticky, and targets at least 24px. The records are stand-ins (the Solr core
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
      test "a #{name} record at #{width} width has no axe violations, one h1, ordered headings, no sideways scroll and nothing sticky" do
        open_record(extra, width)

        assert_accessible(tags: AXE_TAGS + WCAG22_TAGS, except: [ "region" ])
        assert_selector "h1", count: 1
        assert_selector ".record-page section.record-summary header.record-header h1"
        assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

        outline = page.evaluate_script("[...document.querySelectorAll('#main-container h1, #main-container h2, #main-container h3')].filter(e => e.getClientRects().length > 0).map(e => e.tagName + ' ' + e.textContent.trim())")
        # the media band comes first in this layout, so its (visually hidden) "Digital assets" h2 may precede the title
        before_title = outline.take_while { |heading| !heading.start_with?("H1") }
        assert before_title.all? { |heading| heading.match?(/\AH2 Digital assets?\z/) }, outline.inspect
        levels = outline.drop(before_title.size).map { |heading| heading[1].to_i }
        assert levels.each_cons(2).all? { |a, b| b <= a + 1 }, "headings skip a level: #{outline.inspect}"
        assert_includes outline, "H2 Object details"
        assert_includes outline, "H2 Copyright and use"

        sticky = page.evaluate_script("[...document.querySelectorAll('#main-container *')].filter(e => e.getClientRects().length > 0 && ['sticky', 'fixed'].includes(getComputedStyle(e).position)).map(e => e.tagName + '.' + e.className)")
        assert_empty sticky

        small = page.evaluate_script(<<~JS)
          [...document.querySelectorAll('.record-actions button, .record-actions a, .digital-assets__toolbar button, .digital-assets__toolbar a')]
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

  test "the media sits on the page, whole, with no dark band and no minimum height; dark only in full screen" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")

    background = page.evaluate_script("getComputedStyle(document.querySelector('.digital-assets')).backgroundColor")
    assert_equal "rgba(0, 0, 0, 0)", background
    assert_equal "0px", page.evaluate_script("getComputedStyle(document.querySelector('.digital-assets__stage')).minHeight")
    image = page.evaluate_script("(() => { const i = document.querySelector('.digital-assets__image'); return [i.clientHeight, window.innerHeight, getComputedStyle(i).objectFit] })()")
    assert_operator image[0], :<=, image[1] * 0.71
    assert_equal "contain", image[2]
  end

  test "an open record's toolbar has the access chip, the licence, labelled buttons and the one Download link; a view-only record has no download link anywhere" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector ".digital-assets__toolbar .digital-assets__access", text: "Open: view and download"
    assert_selector ".digital-assets__toolbar a.digital-assets__primary[download]", text: "Download image"
    assert_selector ".digital-assets__toolbar button", text: "Media information"

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
      assert_selector ".digital-assets__toolbar a.digital-assets__primary[download]", text: "Download image"
      assert_selector ".digital-assets__licence", text: "CC BY"
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
      assert_no_selector ".record-page img[src*='/digital-assets/']"
      layout = page.evaluate_script("document.querySelector('.record-page').outerHTML")
      assert_not_includes layout, "/digital-assets/"
    end
  end

  test "the media band spans the page; from 1024px the details and the Copyright card are two columns, below it one column in the same order" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    band, details, side = %w[.record-band .record-main__details .record-main__side].map { |selector| page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    assert_operator details["top"], :>=, band["bottom"]
    assert_operator side["left"], :>=, details["right"]

    open_record(VARIANTS.fetch("one image, open"), "phone")
    # one column: summary, actions, details, then the Copyright card
    details, copyright = %w[.record-main__details .record-copyright].map { |selector| page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    assert_operator copyright["top"], :>=, details["bottom"]
  end

  test "the Copyright card is always open and states the record's rights, on a phone and a desktop" do
    %w[phone desktop].each do |width|
      open_record({}, width)
      assert_no_selector "details.record-accordion"
      assert_selector "aside.record-copyright h2", text: "Copyright and use"
      assert_selector "aside.record-copyright", text: "Rights held by the University"
      assert_selector "aside.record-copyright a[href='/help#copyright']", text: "About copyright and terms of use"
    end
  end

  test "the Tab key moves through the record page in the order it reads, and each stop shows a focus ring" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    # start on the last control before the media band (the band comes first in this layout, then the title and the actions)
    page.evaluate_script(<<~JS)
      (() => { const all = [...document.querySelectorAll('a[href], button, input, select, summary, [tabindex]:not([tabindex="-1"])')].filter(e => e.getClientRects().length > 0 && !e.disabled),
                     first = all.findIndex(e => e.closest('.record-band')); all[first - 1].focus() })()
    JS

    stops = 16.times.map do
      page.driver.browser.keyboard.type(:Tab)
      page.evaluate_script(<<~JS)
        (() => { const e = document.activeElement, t = e.type === 'checkbox' ? e.closest('label') : e, s = getComputedStyle(t); return { text: (e.textContent || e.value || '').trim().replace(/\\s+/g, ' ').slice(0, 30), ring: s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) >= 2 } })()
      JS
    end
    texts = stops.map { |stop| stop["text"] }

    assert stops.all? { |stop| stop["ring"] }, stops.reject { |stop| stop["ring"] }.inspect
    # the media band's buttons and toolbar, then the header (Copy), in that order
    order = [ "Zoom and pan", "Media information", "Full screen", "Download image", "Copy" ].map { |label| texts.index { |text| text.include?(label) } }
    assert_equal order.compact.sort, order.compact, texts.inspect
    assert_operator order.compact.size, :>=, 4, texts.inspect
  end
end
