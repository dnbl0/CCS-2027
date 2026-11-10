require "application_system_test_case"

# The home page's "Explore the collections" section (NexusCcs::ExploreComponent) in a real browser, at a desktop and a phone width: axe (WCAG 2.2 AA),
# 44px targets, no sideways scroll, the disclosures (open from tablet width, closed on a phone), the length on a phone, and no layout shift.
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

  def small_targets
    page.evaluate_script("[...document.querySelectorAll('.explore a, .explore summary')].filter(e => e.getBoundingClientRect().width > 0 && e.getBoundingClientRect().height < 44).map(e => e.textContent.trim())")
  end

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

  test "on a desktop: no axe violations (WCAG 2.2 AA), three tiles in a row, targets of 44px, the lists open" do
    keep(counts)
    page.current_window.resize_to(1440, 900)
    visit "/"

    assert_selector "section.explore li.explore__tile", count: 6
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    assert_empty small_targets
    assert_not sideways_scroll?
    tops = page.evaluate_script("[...document.querySelectorAll('.explore__tile')].map(t => Math.round(t.getBoundingClientRect().top))")
    assert_equal 1, tops.first(3).uniq.size, "the first three tiles are in one row"
    assert_operator tops[3], :>, tops[0]
    assert_selector "details.explore__disclosure[open]", count: 2
    assert_selector ".explore__disclosure a.explore__link", text: "Australia"
    assert_no_selector "section.explore img"
  end

  test "on a phone: no axe violations, rows of 44px or more, no sideways scroll, the section about a screen and a half, the disclosures closed until opened" do
    keep(counts)
    page.current_window.resize_to(390, PHONE_HEIGHT)
    visit "/"

    assert_selector "section.explore li.explore__tile", count: 6
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    assert_empty small_targets
    assert_not sideways_scroll?
    assert_no_selector "details.explore__disclosure[open]"
    assert_no_selector ".explore__disclosure a.explore__link", text: "Australia"
    height = page.evaluate_script("document.querySelector('section.explore').getBoundingClientRect().height")
    assert_operator height, :<=, PHONE_HEIGHT * 1.6, "the Explore section is #{height.round}px tall on a phone"

    find("summary", text: "Places").click
    assert_selector ".explore__disclosure a.explore__link", text: "Australia"
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
  end

  test "with example images the section has no axe violations, the picture is whole and the Indigenous Collections tile is still text only" do
    keep(counts(with_image: true))
    visit "/"

    assert_selector "section.explore img.explore__image", count: 1
    assert_selector "li.explore__tile:nth-child(1) img"
    assert_no_selector "li.explore__tile:nth-child(5) img"
    assert_equal "contain", page.evaluate_script("getComputedStyle(document.querySelector('.explore__image')).objectFit")
    assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
  end

  test "the whole tile is the link: the link fills the tile" do
    keep(counts)
    visit "/"

    assert_selector ".explore__tile:nth-child(2) > a.explore__tile-link"
    box = page.evaluate_script("(() => { const t = document.querySelector('.explore__tile:nth-child(2)').getBoundingClientRect(), l = document.querySelector('.explore__tile:nth-child(2) a').getBoundingClientRect(); return [t.width - l.width, t.height - l.height] })()")
    assert_operator box.map(&:abs).max, :<=, 2
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
