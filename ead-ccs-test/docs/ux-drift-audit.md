# UX and drift audit (26 Nov 2026, design/home-bento after 84e10fb)

Read-only audit of the local site (http://127.0.0.1:3087) and the code. 37 pages at 1440px and a phone width (Chrome's minimum, 500px),
each with axe (WCAG 2.2 AA), sideways scroll, broken pictures, script errors, heading order, duplicate ids and small targets checked;
plus screenshots and a code survey. Fix order is the list order within each part. Companion: `docs/handover-drift-fixes.md`.

Clean everywhere: no axe violations on any real page, no sideways scroll, no script errors, no duplicate ids, no skipped heading levels,
one h1 a page. (The 404 page's axe failures were Rails' development error page, not the site's: not a finding.)

## A. Defects a visitor meets (fix first)

| # | Where | What is wrong | Fix |
|---|---|---|---|
| A1 | Every page, first visit | The cookie notice sits above the header, fills ~40% of a phone's first screen, and shows "[Placeholder wording: the University to approve this notice.]" | A slim bar at the foot of the window; keep the note out of the visitor's view until the University approves (ask Dean) |
| A2 | Places map, phone | The floating "Show map" button sits on top of the region chips ("Oceania" hidden under it) | Float it at the foot of the window, clear of the chips |
| A3 | Places map, phone | The region chips run off the right edge with no hint there are more | Wrap them, or fade the edge |
| A4 | Hub search box, phone | Its placeholder is cut off ("…such as photograph or med") | Shorter placeholder ("e.g. photograph") or let the label carry the example |
| A5 | Phone, every page | The breadcrumb strip shows only the Saved button: the trail itself is gone, so there is no way up a level | Show a one-step "← Browse" link on phones |
| A6 | Maker page | "Made 1816 to 2019." under a person born 1882, died 1961: it is the span of the records' dates, read as the maker's | Say what it is: "Records dated 1816–2019", or leave it out for people |
| A7 | Period page | "Made 1900 to 1999." repeats the title (1900–1999) | Leave it out on period pages |
| A8 | Home page | Four pictures from the University's own sites fail to load (museumsandcollections, library, safes …unimelb.edu.au `__data/assets/image/...`) | Copy them into the site or link current addresses; show the tile without a broken picture meanwhile |
| A9 | Period page breadcrumb | "Browse › Explore by time › 1900–1999": the page is now called Time | Use BrowseHubs' title (comes with drift fix 2) |
| A10 | Themes, stories, Discover | Breadcrumb puts them under Browse ("Browse › Themes") though their addresses are /themes, /stories, /discover | Decide one home for them (Dean) and make trail and address agree |
| A11 | Themes and stories | Titles and text still say "(placeholder)" / lorem ipsum, and they are in the menu | Hide from the menu until the wording is approved (Dean) |
| A12 | Maker page | "Roles creator, artist, maker": lower-case data shown raw beside capitalised labels | Capitalise each role as other values are |

## B. Drift and inconsistency a visitor can see

| # | What differs | Today | One way |
|---|---|---|---|
| B1 | Page heads | 4 families: navy banner (search, record, help, about, saved, lists, history, advanced, compare, discover); white centred serif (Browse template, /browse, themes, stories); picture strip then centred title (period, collection, theme); centred title with no picture (maker, story) | Two at most: the navy banner for tools and help, the white centred head for collections content; entity pages always lead with their picture strip |
| B2 | Record cards | Search results and Discover use `ResultCardComponent`; maker, period, collection, story pages, More like this and Looks similar use `RecordCardComponent`: two designs for one thing | One record card |
| B3 | Names for a record | "record" (315 uses) but also "item" (21: record page's access notices, help, advanced search "Find items that match"), "object" (34), "work", "asset" | "record" for the catalogue entry, "image"/"file" for its media |
| B4 | A–Z | "A–Z" (9), "A to Z" (4), "A-Z" (1) | "A–Z" |
| B5 | "See all" links | "See all …", "See every …", "See them all in the search", "View full record"/"View the full record", "Explore its records", "Explore the period" | One verb per job: "See all [things]" to a list, "Open the record" to a record |
| B6 | Map words | "Show map" and "Show the map"; "See places on a map" and "See the places on a map" | One each |
| B7 | Filter label case | "With Digital Asset", "Collection Title" (Title Case) beside sentence-case labels elsewhere | Sentence case (the pill now says "With digital asset") |
| B8 | Primary actions | `btn btn-primary` (light blue), `btn-outline-primary`, `arrow-link`, `places-chip`, and page-specific buttons (`compare-actions__button`, `results-empty__button`, `selection-bar__button`) | Primary button, secondary button, arrow link: three |
| B9 | Focus ring | 3px (60 rules), 2px (14), and four other colour tokens | One ring: 3px `--ccs-focus-ring` |
| B10 | Empty / unavailable messages | ~7 designs, wording "right now / just now / later / shortly" | One component and one sentence |
| B11 | Menu labels vs page titles | Menu "Explore by place/time/colour"; pages "Places/Time/Colours"; menu lacks Materials and Named collections; order differs from /browse | One list (drift fix 2) |
| B12 | Time | Four schemes (home carousel, Time All, Timeline, period pages) | One (drift fix 3) |
| B13 | Breadcrumbs | Drawn by the header (PageChrome) on some pages and by the page (PageBreadcrumbsComponent) on others | One (drift fix 4) |
| B14 | Titles | Error and default titles use " - ", the rest " — " | " — " |

## C. Drift in the code (no visible fault yet; causes the above)

- Ways in listed in ~6 places (drift fix 2). Category intros duplicated (BrowseHubs and categories_themes_stories.en.yml).
- Two mosaic systems: `CardLayoutComponent` (only ever `layout: :mosaic`, 4 uses) and `MosaicComponent` (7 uses). Keep one.
- `CardSectionComponent` is used nowhere (and its test and `card_tiles.css` rules): delete.
- Card/tile components: Stack, Cluster, CardCarousel, FeatureCarousel, SimpleListing, Mosaic, CardLayout, ExploreCard, RecordCard,
  ResultCard: document each one's single job in `docs/card-layouts.md`, merge overlaps.
- ~245 of ~970 CSS class names match no markup (some built in code): old browse-filter, browse-list, browse-facts, browse__*, explore__*,
  time-chart families.
- ~20 breakpoint values (767/767.98/768/769, 900/899/901, 1023/1024 …): one set of tokens.
- 61 raw hex colours in 11 CSS files (static_shared.css 18, bootstrap variables 13, colours.css 11 are the swatches and fine).
- "N records" phrase in ~8 locale keys (now mostly unused after the counts removal: delete the dead keys).
- Two pagers (Browse's `browse_entities/_pager` and Blacklight's).
- Stale docs: `docs/categories-themes-stories.md` (CategoriesController deleted), `docs/blacklight-features.md` notes.

## Suggested order

1. A1–A8 (visible defects, small).
2. Drift fixes 2–4 from the handover (they also close A9, B11–B13).
3. B1–B10 (one page head, one record card, one wording set, one button set, one focus ring, one empty message).
4. Part C clean-up.

Decisions for Dean: A1 (cookie note wording), A10 (where themes/stories/Discover live), A11 (hide placeholder pages from the menu).
