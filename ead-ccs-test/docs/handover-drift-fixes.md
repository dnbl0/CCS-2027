# Handover: drift fixes on design/home-bento (25 Nov 2026)

Read `docs/handover-home-bento.md` first (where things are, how to run and test, Dean's rules). This file is the work in flight.

## Dean's new standing rule: NO COUNTS on the site
No record/item counts anywhere: tiles, A–Z lists, chips, strips, carousels, map pins/popups, colour cards, summaries, "See all N" links,
meta descriptions. KEEP: the search results page's total and its filter (facet) counts, and the visitor's own counts (saved records,
lists, selections). Dean has asked for this many times: never add a count to a new layout. Tests should assert no "N records" text.

## Last commit state
Last finished commit: `104018a` (every page under /browse on one template: BrowseHubs + browse/_template + browse/_views; time,
places, colours have a third tab ?view=timeline|map|spectrum). The commit after it is **WIP: counts removal, half done, tests not run**.

## Task list (Dean approved this order, 25 Nov)
1. **Remove every count** (IN PROGRESS, see below), then add a test that fails if "N records" shows on /, /browse, a hub, its A–Z, the
   timeline, map, spectrum, an entity page and a collection page.
2. **One list of ways in.** Today it is written out in ~6 places: `BrowseHubs::HUBS`, `Categories::DIMENSIONS`,
   `Browse::Cards` (CARD_FIELDS, LAYOUT_BY_HUB), `CategoriesHelper::BROWSE_SECTIONS`/`CATEGORY_LAYOUTS`, `HeaderComponent#browse_more_links`,
   sitemaps (`Browse::SitemapPaths`, `DiscoverySitemap`). Drive menu, /browse, sitemap and titles from BrowseHubs. Menu labels must
   match page titles ("Places", "Time", "Colours", not "Explore by …"); menu lacks Materials and Named collections; order should match
   /browse. /browse's "Places" section shows regions and "Time" shows eras: make them match their pages. Category intros are duplicated
   in BrowseHubs and `categories_themes_stories.en.yml`.
3. **One time scheme.** Four exist: home carousel (`ExploreEntryPoints` periods: "Up to 1799", 1800–1899 … "2000 to today"),
   Time All (`BrowseHubs.periods`: before 1000, centuries to 1799, decades), Timeline (`Explore::Timeline`: centuries from 3000 BCE,
   "Earlier"), period pages (`Browse::Periods`, from 1000, titled "— Periods —"; should say Time).
4. **One page head, one "can't show now" message, one breadcrumb mechanism.** Heads: browse/_template, browse/_page_head (a copy:
   /browse, themes, stories), place-page head (entity, collection, story), PageBannerComponent (saved, lists, help, errors, unavailable),
   catalog/unavailable (h1 styled h3). ~7 unavailable designs, wording "right now/just now/later/shortly". Breadcrumbs: PageChrome trail
   in the header vs PageBreadcrumbsComponent drawn by the page. Error page and default titles use " - " not " — ".
5. **Clean-up.** ~245 of ~970 CSS class names match no markup (some built in code: check before deleting; e.g. colours__swatch--*
   are dynamic). Old families: browse-filter, browse-list, browse-facts, browse__*, explore__*, time-chart. ~20 breakpoint values
   (767/767.98/768/769…): pick one set. 61 raw hex colours in 11 CSS files (static_shared.css, record_classic.css …). "N records" phrase
   defined in ~8 locale keys. Two pagers (browse_entities/_pager vs Blacklight). Stale docs: `docs/categories-themes-stories.md`
   (CategoriesController was deleted). Hub tabs swap in a Turbo frame but the explorer tab reloads the page (note, maybe fine).

## Status (25 Nov, later)
- **Step 1, counts: DONE.** No counts on any page outside search (checked: home, /browse, every hub view, timeline, map, spectrum, entity,
  period, collection, themes, stories), the header Browse menu, map pins (now plain dots), page descriptions. Search results keep their
  total and filter counts. Guard test: `test/integration/no_counts_test.rb` (extend it when you touch a page). Full suite passes.
- **Also done (Dean's request):** quick filters removed (not a business requirement); the With Digital Asset pill reads "With digital
  asset" / "Without digital asset" with no "> Yes" (`ConstraintsComponent::DigitalAssetPill`, `HistoryFilterPillComponent`).
- **Flaky in a batch, pass alone:** browse_test "filter box … opens with Enter" and explore_pages_test "periods … a century opens its own
  page": the click to an entity page is not followed when run after other system tests (the page itself works in a browser). Look at
  Turbo prefetch between tests if it persists. Known failure still: colours "Looks similar" (local index lacks the records).
- **Next:** the full UX and drift audit is `docs/ux-drift-audit.md` (26 Nov): do its part A, then step 2 here (one list of ways in), then 3, 4, 5.

## Counts removal: what was changed (for reference)
- `PlacesHelper`: hub_tile, facet_tile (signature now `facet_tile(label, path, picture)`, callers updated), category_tile: text nil.
- browse/hub.html.erb: no list counts, region chip counts, "See every … (N)", "Showing 1–120 of N"; status/heading are words only.
- Entity page (browse_entities/showcase): summary is the date span only; "See all its records"; collections heading "Collections",
  no per-collection count. Collection page (collection_landings/_showcase), stories/show: no counts.
- Timeline (explore/time): strip items named without counts, **bars removed** (they showed quantity), note without busiest count,
  picture wall has no count (explore/_picture_wall lost its `count:` local), eras summary/chips no counts.
- Colours (colours/index): swatch names only, no card or wall counts.
- Locales updated: browse.en.yml (every, see_all, collections_heading, descriptions without %{count}), explore_pages.en.yml (time
  strip_item/strip_note/see_all/eras_folded), colours.en.yml (see_all), categories_themes_stories.en.yml (see_all, more_results).
- CSS removed: explore-strip__bar, picture-wall__count, colour-card__count.

## Counts removal: was still to do (now done)
- **explore/places.html.erb**: line ~47 consent heading count, ~82 place-tile__count, ~97 "Every place … (N)", ~101/108 region/country
  counts; **explore/_entries.html.erb** browse__count.
- **place_explorer_controller.js**: pin badges show numbers (`badge()`), group pins ("N places, N records"), popup record count,
  "more" list counts, show_more "(N more)", status "59 places". Keep `place.count` for sizing/fitting (not shown). Make pins a plain
  dot (name = place label; group name e.g. "Several places here: zoom in"); words in explore_pages.en.yml `places.explorer.*`
  (consent_heading, shown*, more, see_records, group, record_one/other, all, records_html, show_more).
- **HeaderComponent**: Browse menu `record_count(item.count)` (header_component.html.erb:58, rb:68) and "Only records with images (N)"
  (html.erb:65). ExploreComponent#count_label (check if used; home showed 0 counts).
- Check /browse sections (CategoriesHelper/_section_cards, CardLayoutComponent, FeatureCarouselComponent eras "N records") and
  home (explore_component) render no counts: `curl -s -b country_acknowledged=1 http://127.0.0.1:3087<path> | sed 's/<[^>]*>/ /g' |
  grep -oE '[0-9][0-9,]* (records?|items?|places)'` should print nothing for every page.
- **Tests to update** (they assert counts): test/integration/explore_pages_test.rb (lines ~46 bars, ~70 wall count), colours_test.rb
  (~43, ~63), discovery_pages_test.rb ("8,638 records", "Prints 8,638 records" A–Z), browse_pages_test.rb (A–Z text includes
  "N records"), browse_entities tests, component tests; system test discovery_pages_test "count stays visible on a phone" (delete or
  invert). Then run the full suite (`RBENV_VERSION=4.0.6 bin/rails test`) and the Browse system tests (see the other handover).
- Update docs/handover-home-bento.md commit table, then commit/push to origin design/home-bento. Do not merge.

## Known test notes
Browse system tests (browse_test, browse_sections_test) were stale before 104018a and are fixed. Known failure still: colours
"Looks similar" (local index lacks records), access_request, responsive record checks.
