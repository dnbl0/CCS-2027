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
    "images with video and audio" => { "licence_type_ssim" => [ "Public domain - Copyright expired" ], "digital_asset_large_paths_ssim" => LARGE, "digital_asset_paths_ssim" => THUMBS,
                                       "digital_media_ssim" => [ "video|video/mp4|/digital-assets/media/v.mp4|Test video", "audio|audio/mpeg|/digital-assets/media/a.mp3|Test audio" ] },
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
        assert_includes outline, "H2 Object details."
        assert_includes outline, "H2 Rights and access."
        small = page.evaluate_script("[...document.querySelectorAll('.viewer-pill button, .viewer-dots button, .viewer-media__thumb, .viewer-chevrons button, .viewer-nav a, .viewer-pillcard a, .viewer-quiet button, .viewer-quiet a')].filter(e => e.getClientRects().length > 0).map(e => e.getBoundingClientRect()).filter(r => r.height < 44 || r.width < 44).length")
        assert_equal 0, small, "a control is smaller than 44px"
        links = page.evaluate_script("[...document.querySelectorAll('.viewer-list__row dd a, .viewer-rights__text a')].filter(e => e.getClientRects().length > 0 && e.getBoundingClientRect().height < 24).length")
        assert_equal 0, links, "a linked value is under 24px high"
      end
    end
  end

  test "controls never cover each other or the sensitivity notice, at every width" do
    SIZES.each_key do |size|
      open_record(VARIANTS.fetch("several images, open"), size)
      boxes = page.evaluate_script("[...document.querySelectorAll('.viewer-pill button, .viewer-dots button, .viewer-media__thumb')].filter(e => { if (e.getClientRects().length === 0) return false; const r = e.getBoundingClientRect(); const hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); return hit && (e === hit || e.contains(hit)) }).map(e => { const r = e.getBoundingClientRect(); return [r.left, r.top, r.right, r.bottom] })")
      boxes.combination(2).each do |a, b|
        overlap = a[0] < b[2] - 1 && b[0] < a[2] - 1 && a[1] < b[3] - 1 && b[1] < a[3] - 1
        assert_not overlap, "two controls overlap at #{size}: #{a} #{b}"
      end
    end

    open_record(VARIANTS.fetch("sensitive"), "desktop")
    gate = page.evaluate_script("document.querySelector('.viewer-media .sensitivity-gate').getBoundingClientRect().toJSON()")
    hero = page.evaluate_script("document.querySelector('.viewer-media__stage').getBoundingClientRect().toJSON()")
    assert_operator gate["top"], :>=, hero["top"] - 1
    assert_operator gate["bottom"], :<=, hero["bottom"] + 1, "the notice sits inside the hero"
  end

  test "the page is a hero, a local navigation, a headline with a pill card, and alternating bands, in that order" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    order = page.evaluate_script("[...document.querySelectorAll('.viewer-hero, .viewer-nav, .viewer-headline, .viewer-band')].map(e => e.id || e.className.split(' ')[0])")
    assert_equal [ "viewer-overview", "viewer-nav", "viewer-headline", "viewer-highlights", "viewer-details", "viewer-rights", "about-this-record" ], order
    assert_selector ".viewer-pillcard .viewer-pillcard__status", text: "Open for download"
    assert_selector ".viewer-pillcard a.viewer-pillcard__button[download]", text: "Download image"
    assert_no_selector ".viewer-data, .viewer-toggle, .viewer-switch, .viewer-bar"
    surfaces = page.evaluate_script("[...document.querySelectorAll('.viewer-band')].map(e => getComputedStyle(e).backgroundColor)")
    assert_equal surfaces.each_cons(2).count { |a, b| a != b }, surfaces.size - 1, "the bands alternate white and grey: #{surfaces.inspect}"
  end

  test "video and audio are in their own band after the headline, never in the hero, and nothing scrolls inside the hero" do
    SIZES.each_key do |size|
      open_record(VARIANTS.fetch("images with video and audio"), size)
      assert_selector "#viewer-files h2", text: "Watch and listen."
      assert_selector "#viewer-files .viewer-files__card video", visible: :all
      assert_selector "#viewer-files .viewer-files__card audio", visible: :all
      assert_no_selector ".viewer-hero video, .viewer-hero audio", visible: :all
      order = page.evaluate_script("[...document.querySelectorAll('.viewer-headline, .viewer-band')].map(e => e.id || e.className.split(' ')[0])")
      assert_equal [ "viewer-headline", "viewer-files", "viewer-highlights" ], order.first(3)
      %w[.viewer-media__picture .viewer-media__stage .viewer-hero].each do |selector|
        inner = page.evaluate_script("(() => { const p = document.querySelector('#{selector}'); return p.scrollHeight - p.clientHeight })()")
        assert_operator inner, :<=, 1, "#{selector} scrolls inside the hero at #{size}"
      end
      assert_equal "hidden", page.evaluate_script("getComputedStyle(document.querySelector('.viewer-media__picture')).overflowY")
    end
  end

  test "the round zoom buttons never cover the picture on a phone" do
    %w[phone narrow].each do |size|
      open_record(VARIANTS.fetch("several images, open"), size)
      assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
      stage = page.evaluate_script("document.querySelector('.viewer-media .deep-zoom__stage').getBoundingClientRect().toJSON()")
      image = page.evaluate_script("document.querySelector('.viewer-media__figure .digital-assets__image').getBoundingClientRect().toJSON()")
      buttons = page.evaluate_script("[...document.querySelectorAll('.viewer-pill button')].filter(e => e.getClientRects().length > 0).map(e => e.getBoundingClientRect().toJSON())")
      assert_operator buttons.size, :>=, 3
      { "zoom stage" => stage, "picture" => image }.each do |name, box|
        buttons.each do |button|
          overlap = button["left"] < box["right"] - 1 && box["left"] < button["right"] - 1 && button["top"] < box["bottom"] - 1 && box["top"] < button["bottom"] - 1
          assert_not overlap, "a zoom button covers the #{name} at #{size}"
        end
      end
    end
  end

  test "Related objects, Similar records and Recently viewed have round buttons from 1024px when a row overflows, and none below" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector "#more-like-this[data-controller=viewer-page]", visible: :all
    page.execute_script(<<~JS)
      const inner = document.querySelector('#more-like-this .more-like-this__inner')
      const card = (n) => '<li class="object-cards__item"><div class="object-card"><div class="object-card__media"></div><div class="object-card__body"><h4><a href="#c' + n + '">Card ' + n + '</a></h4></div></div></li>'
      const section = (id, title, cls) => '<section id="' + id + '" class="object-cards object-cards--nested ' + cls + '"><div class="object-cards__inner"><h3 class="object-cards__heading">' + title + '</h3><ul class="object-cards__list">' + [1,2,3,4].map(card).join('') + '</ul></div></section>'
      inner.insertAdjacentHTML('beforeend', section('t-related', 'Related objects', '') + section('t-recent', 'Recently viewed', 'object-cards--compact'))
    JS
    assert_selector "#t-related .viewer-chevrons button[aria-label='Previous in Related objects'][disabled]", wait: 5
    assert_selector "#t-related .viewer-chevrons button[aria-label='Next in Related objects']:not([disabled])"
    assert_selector "#t-recent .viewer-chevrons button[aria-label='Next in Recently viewed']"
    small = page.evaluate_script("[...document.querySelectorAll('.viewer-chevrons--row button')].filter(e => e.getClientRects().length > 0).filter(e => e.getBoundingClientRect().width < 44).length")
    assert_equal 0, small

    find("#t-related .viewer-chevrons button[aria-label='Next in Related objects']").click
    assert_selector "#t-related .viewer-chevrons button[aria-label='Previous in Related objects']:not([disabled])", wait: 5

    open_record(VARIANTS.fetch("several images, open"), "phone")
    page.execute_script("document.querySelector('#more-like-this .more-like-this__inner').insertAdjacentHTML('beforeend', '<section class=\"object-cards\"><div class=\"object-cards__inner\"><h3 class=\"object-cards__heading\">Related objects</h3><ul class=\"object-cards__list\"><li class=\"object-cards__item\">A</li><li class=\"object-cards__item\">B</li><li class=\"object-cards__item\">C</li></ul></div></section>')")
    assert_selector ".viewer-chevrons--row", visible: :all, wait: 5
    assert_no_selector ".viewer-chevrons--row", visible: true
  end

  test "the details group is not named as its headline, and Compare images has the compare icon" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    headings = page.evaluate_script("[...document.querySelectorAll('#viewer-details h2, #viewer-details h3')].map(e => e.textContent.trim())")
    assert_equal [ "Object details.", "The object" ], headings.first(2)
    assert_selector ".viewer-quiet .compare-actions__link svg", visible: :all
    assert_selector ".viewer-quiet .compare-actions__link", text: "Compare images"
  end

  test "the hero is a light gradient with the picture whole, and no dark box, except in full screen" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
    image = page.evaluate_script("getComputedStyle(document.querySelector('.viewer-hero')).backgroundImage")
    assert_match(/gradient/, image)
    zoom = page.evaluate_script("getComputedStyle(document.querySelector('.viewer-media .deep-zoom__stage')).backgroundColor")
    assert_equal "rgba(0, 0, 0, 0)", zoom
    height = page.evaluate_script("document.querySelector('.viewer-media__stage').getBoundingClientRect().height")
    assert_operator height, :<=, 46 * 16 + 1
  end

  test "the local navigation sticks once the hero is past, its anchors work, and a focused control is not hidden under it" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_equal "sticky", page.evaluate_script("getComputedStyle(document.querySelector('.viewer-nav')).position")
    assert_selector ".viewer-nav .viewer-nav__title", text: "Untitled [Timber eucalypt specimen cabinet]"
    assert_selector ".viewer-nav a.viewer-nav__button", text: "Download image"
    page.execute_script("document.querySelector('.viewer-nav a[href=\"#viewer-rights\"]').click()")
    assert_selector "#viewer-rights"
    page.evaluate_script("document.querySelector('.persistent-link__copy').focus()")
    bar = page.evaluate_script("document.querySelector('.viewer-nav').getBoundingClientRect().bottom")
    top = page.evaluate_script("document.querySelector('.persistent-link__copy').getBoundingClientRect().top")
    assert_operator top, :>=, bar - 1, "the focused control is under the local navigation"

    open_record(VARIANTS.fetch("several images, open"), "phone")
    assert_no_selector ".viewer-nav", visible: true
  end

  test "the one pill button follows the tier: Download image, Request access, or Contact us" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".viewer-nav__button[download]", text: "Download image"
    open_record(VARIANTS.fetch("request-only"), "desktop")
    assert_selector ".viewer-pillcard__button[href*=access_requests]", text: "Request access"
    assert_selector ".viewer-pillcard__status", text: "Access by request"
    assert_no_selector "a[download]"
    open_record(VARIANTS.fetch("view-only"), "desktop")
    assert_selector ".viewer-pillcard__button", text: "Contact us"
    assert_selector ".viewer-pillcard__status", text: "View only"
    assert_selector ".viewer-rights__card a[href*=access_requests]", text: "Request access to download this item"
    assert_no_selector "a[download]"
    open_record(VARIANTS.fetch("imageless"), "desktop")
    assert_selector ".viewer-pillcard__button", text: "Contact us"
    assert_no_selector ".viewer-pillcard__status"
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
    page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').focus()")
    page.driver.browser.keyboard.type("0")
    assert_selector ".viewer-pill button[aria-label='Zoom out'][disabled]", wait: 8
  end

  test "the mouse wheel is left to the page everywhere over the hero, and the hero does not scroll inside" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".deep-zoom__stage .openseadragon-canvas", visible: :all, wait: 10
    not_prevented = page.evaluate_script("document.querySelector('.deep-zoom__stage .openseadragon-canvas').dispatchEvent(new WheelEvent('wheel', { deltaY: 200, bubbles: true, cancelable: true }))")
    assert not_prevented, "the viewer swallows the mouse wheel"
    assert_selector ".viewer-pill button[aria-label='Zoom out'][disabled]" # and it did not zoom
    inner = page.evaluate_script("(() => { const p = document.querySelector('.viewer-media__picture'); return p.scrollHeight - p.clientHeight })()")
    assert_operator inner, :<=, 1, "the picture area scrolls inside the hero"
  end

  test "Previous, Next and the thumbnails change the picture in sequence, the arrows stop at the ends, the change is announced and the download follows" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    assert_selector ".viewer-dots button[aria-label='Previous image'][disabled]"
    assert_selector "[data-media-viewer-target=counter]", text: "Image 1 of 2", visible: :all

    find(".viewer-dots button[aria-label='Next image']").click
    assert_selector "[data-media-viewer-target=counter]", text: "Image 2 of 2", visible: :all
    assert_selector ".viewer-media__thumb.is-current[aria-label='Display image 2 of 2'][aria-current=true]", count: 1
    assert_selector ".viewer-dots button[aria-label='Next image'][disabled]"
    assert_equal LARGE.last, page.evaluate_script("document.querySelector('.digital-assets__image').getAttribute('src')").split("?").first
    assert_equal LARGE.last, page.evaluate_script("document.querySelector('.viewer-nav__button').getAttribute('href')").split("?").first, "the download follows the image shown"

    find(".viewer-dots button[aria-label='Previous image']").click
    assert_selector "[data-media-viewer-target=counter]", text: "Image 1 of 2", visible: :all
  end

  test "the cards scroll with round chevrons that stop at the ends, and a card opens its picture in the hero" do
    open_record(VARIANTS.fetch("several images, open"), "phone")
    assert_selector ".viewer-cards .viewer-card", count: 2
    assert_selector ".viewer-chevrons button[aria-label='Previous pictures'][disabled]"

    find(".viewer-card[aria-label='Show picture 2 of 2 in the viewer']").click
    assert_selector "[data-media-viewer-target=counter]", text: "Image 2 of 2", visible: :all
    assert_equal LARGE.last, page.evaluate_script("document.querySelector('.digital-assets__image').getAttribute('src')").split("?").first
    assert_operator page.evaluate_script("document.querySelector('.viewer-hero').getBoundingClientRect().top"), :<, 200, "the hero is scrolled into view"
  end

  test "Share opens the Share and embed dialog from the quiet row" do
    open_record(VARIANTS.fetch("several images, open"), "desktop")
    find(".viewer-quiet .share__button").click
    assert_selector "dialog[open]"
  end

  test "the default address is not the viewer layout" do
    open_record(VARIANTS.fetch("view-only"), "desktop", layout: nil)
    assert_no_selector ".viewer-page"
    assert_selector ".record-hero"
  end
end
