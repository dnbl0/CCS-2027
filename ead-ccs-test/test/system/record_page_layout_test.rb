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
        assert_selector "header.record-header .record-header__kicker"
        assert_selector ".record-subnav", visible: :all
        assert_equal false, page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

        outline = page.evaluate_script("[...document.querySelectorAll('#main-container h1, #main-container h2, #main-container h3')].filter(e => e.getClientRects().length > 0).map(e => e.tagName + ' ' + e.textContent.trim())")
        assert_equal "H1", outline.first.split.first
        levels = outline.map { |heading| heading[1].to_i }
        assert levels.each_cons(2).all? { |a, b| b <= a + 1 }, "headings skip a level: #{outline.inspect}"
        assert_includes outline, "H2 Object details"
        assert_includes outline, "H2 Copyright and use"

        sticky = page.evaluate_script("[...document.querySelectorAll('#main-container *')].filter(e => e.getClientRects().length > 0 && !e.closest('.record-subnav') && ['sticky', 'fixed'].includes(getComputedStyle(e).position)).map(e => e.tagName + '.' + e.className)")
        assert_empty sticky

        small = page.evaluate_script(<<~JS)
          [...document.querySelectorAll('.record-actions button, .record-actions a, .digital-assets__overlay button')]
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

  test "the viewer is a soft stage in the left column, the image whole at its own shape and never a dark box; dark only in full screen" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")

    stage = page.evaluate_script("getComputedStyle(document.querySelector('.digital-assets__stage')).backgroundColor").scan(/\d+/).first(3).map(&:to_i)
    assert_operator stage.min, :>=, 230, "the stage is a light tint, not a dark box: #{stage}"
    viewer, buy = %w[.record-hero__viewer .record-hero__buy].map { |selector| page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    assert_operator viewer["right"], :<=, buy["left"], "the viewer is the left column"
    assert_in_delta 0.58 / 0.42, viewer["width"] / buy["width"], 0.15
    image = page.evaluate_script("(() => { const i = document.querySelector('.digital-assets__image'); return [i.clientHeight, window.innerHeight, getComputedStyle(i).objectFit] })()")
    assert_operator image[0], :<=, [ image[1] * 0.78, 760 ].min + 1
    assert_equal "contain", image[2]
  end

  test "an open record's access card has one Download image button; the viewer has its round controls; a view-only record has no download link anywhere" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector ".access-card__headline", text: "Download this image"
    assert_selector ".access-card a.access-card__primary[download]", text: "Download image"
    assert_selector ".digital-assets__overlay button", text: "Media information"
    assert_selector ".digital-assets__facts .digital-assets__access", text: "Open: view and download"

    open_record(VARIANTS.fetch("several images, view-only"), "desktop")
    assert_selector ".access-card__reason a[href*=access_requests]"
    assert_no_selector "a[download], .access-card__primary"
    assert_no_selector ".digital-assets a[href*='/digital-assets/']"
  end

  test "a request-only or sensitive record has no asset address in its page" do
    %w[request-only sensitive].each do |name|
      open_record(VARIANTS.fetch(name), "desktop")
      assert_no_selector ".record-page img[src*='/digital-assets/']"
      assert_no_selector "a[download]"
      markup = page.evaluate_script("document.querySelector('.record-page').outerHTML")
      assert_not_includes markup, "/digital-assets/"
    end
  end

  test "from 1200px the viewer and the record sit side by side with the specifications centred under them; below it one column, in markup order" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    rect = ->(selector) { page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()") }
    viewer, buy, specs = %w[.record-hero__viewer .record-hero__buy .record-specs].map(&rect)
    assert_operator buy["left"], :>=, viewer["right"]
    assert_operator specs["top"], :>=, [ viewer["bottom"], buy["bottom"] ].max - 1
    assert_operator specs["width"], :<=, 960 + 70, "the specifications are a centred 960px column"

    open_record(VARIANTS.fetch("one image, open"), "phone")
    viewer, buy, specs = %w[.record-hero__viewer .record-hero__buy .record-specs].map(&rect)
    assert_operator buy["top"], :>=, viewer["bottom"] - 1
    assert_operator specs["top"], :>=, buy["bottom"] - 1
    assert_no_selector ".record-subnav", visible: true
  end

  test "the sub-navigation shows from 1200px, its anchors reach their sections, and a focused control is not hidden under it" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector ".record-subnav .record-subnav__title", text: "Untitled [Timber eucalypt specimen cabinet]"
    assert_equal "sticky", page.evaluate_script("getComputedStyle(document.querySelector('.record-subnav')).position")
    page.evaluate_script("document.querySelector('.record-subnav a[href=\"#about-this-record\"]').click()")
    assert_selector "#about-this-record"
    # focus something far down: the browser's scroll padding keeps it clear of the bar
    page.evaluate_script("document.querySelector('.persistent-link__copy').focus()")
    bar = page.evaluate_script("document.querySelector('.record-subnav').getBoundingClientRect().bottom")
    top = page.evaluate_script("document.querySelector('.persistent-link__copy').getBoundingClientRect().top")
    assert_operator top, :>=, bar - 1, "the focused control is under the sub-navigation"
  end

  test "on a phone the sections are accordions with Object details open; from 768px they are open and fixed" do
    open_record({}, "phone")
    assert_selector "details.record-accordion", count: 3
    assert_selector "details#record-about-details, details.record-accordion[open]", minimum: 1
    states = page.evaluate_script("[...document.querySelectorAll('details.record-accordion')].map(d => [d.querySelector('h2').textContent.trim(), d.open, d.querySelector('summary').getBoundingClientRect().height >= 44])")
    assert_equal [ [ "Object details", true, true ], [ "Copyright and use", false, true ], [ "About this record", false, true ] ], states

    find("details.record-copyright summary").click
    assert_selector "details.record-copyright[open]"
    assert_selector ".record-copyright", text: "Rights held by the University"

    open_record({}, "desktop")
    assert_equal [ true, true, true ], page.evaluate_script("[...document.querySelectorAll('details.record-accordion')].map(d => d.open)")
  end

  test "the Tab key moves through the viewer, the record and the access card in the order it reads, and each stop shows a focus ring" do
    open_record(VARIANTS.fetch("one image, open"), "desktop")
    assert_selector ".deep-zoom__toggle", visible: true
    page.evaluate_script("document.querySelector('.deep-zoom__toggle').focus()")
    assert_equal "Zoom and pan", page.evaluate_script("document.activeElement.textContent.trim()")

    stops = 14.times.map do
      page.driver.browser.keyboard.type(:Tab)
      page.evaluate_script(<<~JS)
        (() => { const e = document.activeElement, t = e.type === 'checkbox' ? e.closest('label') : e, s = getComputedStyle(t); return { text: (e.textContent || e.value || '').trim().replace(/\\s+/g, ' ').slice(0, 30), ring: s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) >= 2 } })()
      JS
    end
    texts = stops.map { |stop| stop["text"] }

    assert stops.all? { |stop| stop["ring"] }, stops.reject { |stop| stop["ring"] }.inspect
    order = [ "Media information", "Full screen", "Grimwade", "Download image", "Save" ].map { |label| texts.index { |text| text.include?(label) } }
    assert_equal order.compact.sort, order.compact, texts.inspect
    assert_operator order.compact.size, :>=, 4, texts.inspect
  end
end
