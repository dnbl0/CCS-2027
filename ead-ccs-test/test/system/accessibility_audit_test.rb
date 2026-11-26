require "application_system_test_case"

# CCS-51 (WCAG 2.2 AA): every kind of page the site has, at a desktop width and a phone width (390px), checked with axe's
# WCAG 2.0/2.1/2.2 A and AA rules and best practices, and for sideways scrolling (WCAG 1.4.10). Each page's problems are
# collected and the test fails once with all of them, so a run lists everything to fix. Other system tests check the
# interactions (keyboard, focus, gates, dialogs) page by page; this one makes sure no page type is left out.
class AccessibilityAuditTest < ApplicationSystemTestCase
  # A record with a picture in whichever core the test runs against (the CI core and the local index have different ids)
  def record_id
    @record_id ||= Blacklight.default_index.connection.get("select", params: { q: "has_digital_asset_bsi:true", rows: 1, fl: "id", wt: "json" })
                              .dig("response", "docs", 0, "id")
  end

  def pages = PAGES.transform_values { |path| path.gsub("RECORD", record_id.to_s) }

  PAGES = {
    "home" => "/",
    "search results" => "/catalog?q=print&search_field=all_fields",
    "no results" => "/catalog?q=zzqxqz&search_field=all_fields",
    "record" => "/catalog/RECORD",
    "advanced search" => "/catalog/advanced",
    "browse" => "/browse",
    "category pages" => "/browse/categories",
    "a category" => "/browse/materials",
    "a theme" => "/browse/themes/twentieth-century-prints",
    "stories" => "/browse/stories",
    "a story" => "/browse/stories/example-story",
    "explore by time" => "/browse/time",
    "explore by place" => "/browse/places",
    "explore by colour" => "/browse/colours",
    "discover" => "/browse/discover",
    "lists" => "/lists",
    "search history" => "/search-history",
    "help" => "/help",
    "about" => "/about",
    "privacy" => "/privacy",
    "accessibility statement" => "/accessibility",
    "language in our records" => "/language-in-our-records",
    "access request form" => "/access-requests/new?document_id=RECORD"
  }.freeze

  WIDTHS = { "desktop" => [ 1440, 900 ], "phone" => [ 390, 844 ] }.freeze

  setup do
    needs_solr
    page.driver.set_cookie("country_acknowledged", "1")
  end

  WIDTHS.each do |width_name, size|
    test "every page type has no axe violations (WCAG 2.2 AA) and no sideways scroll at #{width_name} width" do
      page.driver.resize(*size)
      problems = pages.filter_map do |name, path|
        visit path
        check(name)
      end
      assert_empty problems, "#{width_name}:\n#{problems.join("\n")}"
    end
  end

  # WCAG 2.4.1 and 2.4.7: the first Tab reaches the skip link, and every control the keyboard reaches shows where the focus is
  # (an outline or a ring), on the pages people use most. Checks the first 30 Tab stops of each.
  test "the first Tab reaches the skip link and every focused control shows a visible focus indicator" do
    page.driver.resize(1440, 900)
    problems = { "home" => "/", "search results" => "/catalog?q=print&search_field=all_fields", "record" => "/catalog/#{record_id}",
                 "browse" => "/browse" }.flat_map do |name, path|
      visit path
      page.execute_script("document.activeElement && document.activeElement.blur(); window.scrollTo(0, 0)")
      stops = Array.new(30) do |index|
        page.driver.browser.keyboard.type(:Tab)
        info = page.evaluate_script(<<~JS)
          (() => {
            const el = document.activeElement
            if (!el || el === document.body) return null
            const r = el.getBoundingClientRect()
            const ringed = (node) => { const s = getComputedStyle(node); return (s.outlineStyle !== "none" && parseFloat(s.outlineWidth) > 0) || (s.boxShadow && s.boxShadow !== "none") }
            // the ring may be on the control or on a box around it (a search field's whole bar, by :focus-within)
            let ring = false
            for (let node = el, depth = 0; node && depth < 4 && !ring; node = node.parentElement, depth++) ring = ringed(node)
            const visible = r.width > 0 && r.height > 0
            return { text: (el.innerText || el.getAttribute("aria-label") || el.value || el.tagName).trim().slice(0, 40), ring, visible, skip: el.matches("a[href^='#']") && /^skip to/i.test((el.innerText || "").trim()) }
          })()
        JS
        [ index, info ]
      end
      first = stops.first&.last
      found = []
      found << "#{name}: the first Tab stop is #{first&.dig('text').inspect}, not the skip link" unless first && first["skip"]
      stops.each do |index, info|
        next unless info && info["visible"]
        found << "#{name}: Tab stop #{index + 1} (#{info['text'].inspect}) shows no focus indicator" unless info["ring"]
      end
      found
    end
    assert_empty problems, problems.join("\n")
  end

  private

  def check(name)
    found = []
    begin
      assert_accessible(tags: AXE_TAGS + WCAG22_TAGS)
    rescue Minitest::Assertion => e
      found << e.message.lines.first(6).join.strip
    end
    scroll = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    found << "scrolls sideways by #{scroll}px" if scroll.to_i > 1
    "#{name}: #{found.join(' | ')}" if found.any?
  end
end
