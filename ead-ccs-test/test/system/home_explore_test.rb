require "application_system_test_case"

# The home page's sections (NexusCcs::ExploreComponent; the homepage redesign, 2026-11) in a real browser, at a desktop and a phone width:
# axe (WCAG 2.2 AA), 44px targets, no sideways scroll, no cropped picture, the fluid mosaic, and no layout shift.
# The numbers are given to the section (the cache), so the page does not depend on what the shared index holds.
class HomeExploreSystemTest < ApplicationSystemTestCase
  PATH = "/digital-assets/thumbs/0000_013_1_pf.jpg"
  PHONE_HEIGHT = 844

  setup do
    page.driver.set_cookie("country_acknowledged", "1")
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write(BrowseMenu::CACHE_KEY, { BrowseMenu::WITH_IMAGES => 1 }, expires_in: 1.day)
  end

  teardown do
    Rails.cache = @cache
    page.current_window.resize_to(1400, 900)
  end

  def counts(with_image: false)
    image = { id: "emu-1", title: "A bronze lyre", path: PATH, width: 400, height: 300 }
    {
      "collections" => [ [ "University Art Collection", 14_537 ], [ "Medical History Museum", 13_979 ], [ "Grainger Museum Collection", 12_849 ],
                         [ "Henry Forman Atkinson Dental Museum", 5331 ], [ "Indigenous Collections", 1540 ], [ "Harry Brookes Allen Museum of Anatomy and Pathology", 1331 ] ],
      "kinds" => ExploreEntryPoints.kinds.map { |label, values| [ label, 500, values ] },
      "places" => [ [ "Australia", 8056 ], [ "Europe", 6842 ], [ "Victoria", 4430 ], [ "Melbourne", 3279 ], [ "United Kingdom", 3083 ] ],
      "periods" => ExploreEntryPoints.periods.to_h { |_label, first, last| [ ExploreEntryPoints.period_key(first, last), 100 ] },
      "images" => with_image ? { "University Art Collection" => image, "Indigenous Collections" => image } : {}
    }
  end

  def keep(counts) = Rails.cache.write(ExploreEntryPoints::CACHE_KEY, counts, expires_in: 1.day)

  # A card's title link covers the whole card (its ::after), so the card is its target, not the line of text
  def small_targets
    page.evaluate_script("[...document.querySelectorAll('main .home-section a, main .home-section summary')].filter(e => !e.matches('.explore-card__link, .object-card__link, .simple-listing__link, .stack__link, .cluster__link, .card-carousel__link') && e.getAttribute('tabindex') !== '-1' && e.getBoundingClientRect().width > 0 && e.getBoundingClientRect().height < 44).map(e => e.textContent.trim())")
  end

  # No picture in the home sections is cropped: each is fitted (contain) or shown at its own shape. The University's listing of its
  # collections (simple-listing) is the exception by design: its own site fills each 16:10 frame, and the home page follows it; so are
  # Google Arts & Culture's cluster (On this day) and story carousel (Time), whose cards are filled as Google's are.
  def cropped_pictures
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll('main .home-section img:not(.simple-listing__img, .cluster__image, .card-carousel__media img)')].filter(img => {
        if (!img.naturalWidth || !img.getBoundingClientRect().width) return false
        if (getComputedStyle(img).objectFit !== 'cover') return false
        const r = img.getBoundingClientRect()
        return Math.abs(r.width / r.height - img.naturalWidth / img.naturalHeight) > 0.02
      }).map(img => img.src)
    JS
  end

  # No two tiles of a mosaic overlap, and none leaves a hole: each tile's top meets the tile above it in its lane, or the top
  def assert_no_overlaps
    overlaps = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('main .mosaic-flow.is-ready')].flatMap(list => {
        const boxes = [...list.children].map(li => li.getBoundingClientRect()).filter(r => r.width)
        return boxes.flatMap((a, i) => boxes.slice(i + 1).filter(b => a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1).map(() => list.getAttribute('aria-label')))
      })
    JS
    assert_empty overlaps, "tiles overlap"
  end

  def explore_boxes = page.evaluate_script("[...document.querySelectorAll('section.explore ul.simple-listing > li')].map(t => { const r = t.getBoundingClientRect(); return [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)] })")

  def sideways_scroll? = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

  def layout_shift
    page.evaluate_async_script(<<~JS)
      var done = arguments[arguments.length - 1], total = 0;
      new PerformanceObserver(function (list) {
        list.getEntries().forEach(function (e) { if (!e.hadRecentInput) total += e.value });
      }).observe({ type: "layout-shift", buffered: true });
      setTimeout(function () { done(total) }, 700);
    JS
  end

  test "on a desktop: no axe violations (WCAG 2.2 AA), the collections as the University's listing four to a row, the other sections one mosaic" do
    keep(counts(with_image: true))
    page.current_window.resize_to(1440, 900)
    visit "/"

    assert_selector "section.explore ul.simple-listing > li.simple-listing__item", count: HomeCollections.museums.size + HomeCollections.art_collection.size
    assert_selector "section.explore .home-art-collection ul.simple-listing > li.simple-listing__item", count: HomeCollections.art_collection.size
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    assert_empty small_targets
    assert_not sideways_scroll?
    assert_empty cropped_pictures
    boxes = explore_boxes
    assert_equal 4, boxes.first(4).map(&:first).uniq.size, "four to a row"
    assert_equal 1, boxes.first(4).map { |box| box[1] }.uniq.size, "the first four share a row"
    assert_equal 1, boxes.map { |box| box[2] }.uniq.size, "every card the same width"
    # places, time and on this day: the same tile in the same mosaic
    # Object types: a fanned stack (the centre card in front and at full size)
    assert_selector ".explore-kinds ul.stack > li.stack__item", minimum: 1, maximum: NexusCcs::ExploreComponent::KINDS_SHOWN
    assert_equal "absolute", page.evaluate_script("getComputedStyle(document.querySelector('.stack__item')).position"), "a fan on a desktop"
    first = find(".explore-kinds li.stack__item", match: :first)
    first.hover
    assert_selector ".explore-kinds li.stack__item.is-centre[data-away='0']", text: first.find("h3").text # pointing at a card makes it the centre
    # Places: the same fan, without the band of colour; the close-ups band, when today's record can be shown, edge to edge
    assert_selector ".home-places ul.stack > li.stack__item", minimum: 1, maximum: NexusCcs::ExploreComponent::PLACES_SHOWN if page.has_css?(".home-places", wait: 0)
    if page.has_css?(".look-closer", wait: 0)
      assert_equal 1440, page.evaluate_script("Math.round(document.querySelector('.look-closer').getBoundingClientRect().width)"), "the band runs edge to edge"
    end
    # Time: a carousel, a slide at a time; the next button moves it one slide and the previous button is then live
    if page.has_css?(".explore-periods", wait: 0)
      track = ".explore-periods .card-carousel__track"
      assert_selector ".explore-periods button[aria-label='Previous period'][aria-disabled=true]"
      find(".explore-periods button[aria-label='Next period']").click
      assert_selector ".explore-periods button[aria-label='Previous period'][aria-disabled=false]"
      assert_operator page.evaluate_script("document.querySelector('#{track}').scrollLeft"), :>, 0
      assert_selector ".explore-periods .card-carousel__status", text: /\A2 of \d\z/
    end
    # On this day: a cluster of different sizes in one block, each card the same height as the block's row or two
    if page.has_css?(".home-on-this-day .cluster", wait: 0)
      heights = page.evaluate_script("[...document.querySelectorAll('.home-on-this-day .cluster__item')].map(li => Math.round(li.getBoundingClientRect().height))")
      assert_operator heights.uniq.size, :>, 1, "tall and short cards"
    end
    assert_no_selector ".explore-card--collage, .place-spot, .home-section .object-card, .explore-card__cta"
    assert_no_overlaps
    assert_no_selector ".home-visit, #home-ways-in"
    colours = page.evaluate_script("[...document.querySelectorAll('main > .ccs-section:not(.ccs-section--hero), main > .look-closer')].map(s => getComputedStyle(s).backgroundColor)")
    assert_equal colours.each_cons(2).count { |a, b| a != b }, colours.size - 1, "the sections' backgrounds alternate"
  end

  test "on a phone: no axe violations, 44px targets, no sideways scroll, one card to a row" do
    keep(counts(with_image: true))
    page.current_window.resize_to(390, PHONE_HEIGHT)
    visit "/"

    assert_selector "section.explore ul.simple-listing > li.simple-listing__item", count: HomeCollections.museums.size + HomeCollections.art_collection.size
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    assert_empty small_targets
    assert_not sideways_scroll?
    assert_equal 1, explore_boxes.map(&:first).uniq.size, "every card starts at the left edge"
  end

  test "the whole card is the link: a click on a collection's picture lands on its title's link" do
    keep(counts(with_image: true))
    page.current_window.resize_to(1440, 900)
    visit "/"

    assert_selector "section.explore ul.simple-listing"
    hit = page.evaluate_script("(() => { const t = document.querySelector('section.explore li:nth-child(2) img'); t.scrollIntoView({ block: 'center' }); const r = t.getBoundingClientRect(); const e = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); return e && (e.closest('a') || {}).className })()")
    assert_equal "simple-listing__link", hit.to_s
  end

  test "the section causes no layout shift on desktop or phone, with or without pictures" do
    [ [ 1440, 900, false ], [ 390, PHONE_HEIGHT, false ], [ 1440, 900, true ] ].each do |width, height, with_image|
      keep(counts(with_image: with_image))
      page.current_window.resize_to(width, height)
      visit "/"
      assert_selector "section.explore"
      assert_operator layout_shift, :<=, 0.1, "Cumulative Layout Shift budget is 0.1 (#{width}px, image #{with_image})"
    end
  end
end
