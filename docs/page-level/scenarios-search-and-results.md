# Scenario catalogue: search, results, filters, advanced search, search history

Source: research agent, 2026-10-12 (code read only; nothing run). Rails paths under `ead-ccs-test/`, static under `public/`.

Key numbers
- Per page: 12, 24, 40 or 96; default 40 (`catalog_controller.rb:21-22`).
- Sort: relevance, date (newest), date (oldest), title (A-Z), title (Z-A). Static has no Z-A.
- Search text: 255 characters max.
- Pagination: current page +/-2, plus first and last, with ellipsis (`1 ... 4 5 6 7 8 ... 74`). Rails `_results_pagination.html.erb:1-5`; Static `search-results.html:1346-1354`.
- Numbers: thousands separators ("1,234 results"), singular "1 result".
- Facet values before "Show all N": 12 for short-value filters, 6 for the rest. Facet search box everywhere except theme, licence, access, film, format.
- Max page: no cap configured.

| ID | Page | Scenario | Type | How reached | What the UI shows | Source | R/S |
|---|---|---|---|---|---|---|---|
| S1 | Any | Search overlay, empty | Happy | header search | Dialog "Search"; placeholder "Search"; Close; no recent block | search_overlay_component.html.erb:1-34 | Both |
| S2 | Any | Overlay with history | Happy | after searches | "Recent searches" up to 5 links newest first + "All recent searches" | search_overlay_component.rb:6 | R |
| S3 | Any | Typeahead | Happy | typing in banner or overlay | Autocomplete from the `suggest` handler | search_banner_component.rb:16 | R |
| S4 | Any | Query over 255 | Edge | typing or pasting | `maxlength=255`; server also trims | query_rules.rb:12-16 | R |
| H1 | Results | Bare front page | Happy | `/` or `/catalog`, no params | Redirects to `f[has_digital_asset][]=with&view=masonry`; "Records with digital assets" switch on | catalog_controller.rb:128-132 | Both |
| H2 | Results | Banner | Happy | any results page | "Search the collections"; "Explore artworks, objects, manuscripts, photographs and recordings held across the University of Melbourne's cultural collections."; search form; "Advanced search" link | search_banner_component.rb:7-8 | Both |
| H3 | Results | Banner summary | Happy | `?q=skull` | "1,234 results for "skull"" replaces the description | search_banner_component.rb:37-44 | R |
| H4 | Results | Toolbar count | Happy | `?q=skull` | h2 "N results for" then pills; "N results" with no query or filters | constraints_component.rb:22-26 | Both |
| H5 | Results | One result | Edge | query matching one record | "1 result" | same | Both |
| H6 | Results | Mosaic (default) | Happy | no `view`, or `view=masonry` | Columns 1 below 632px, 2 at 632, 3 at 928; with sidebar 2 at 992, 3 at 1264, 4 at 1560, 5 at 1856, 6 at 2152 | results_layout.css:83-116 | R |
| H7 | Results | List view | Happy | `view=list` | Below 768 vertical card; 768+ horizontal (text left, 324x182 image right); 2 columns from 1800px | result_card.css:176-215 | R |
| H8 | Results | Card with image | Happy | thumbnail exists | 16:9 lazy image, h3 title (styled like an h5), up to 3 lines (creator, object type, collection), Save control | result_card_component.html.erb | Both |
| H9 | Results | Card without image | Edge | no `thumbnail_path_ssi` | Text only. Mosaic shows a placeholder cycling 3 shapes (landscape, portrait, square); list shows nothing and text takes full width | catalog_controller.rb:42-47 | R |
| H10 | Results | Missing fields, long title | Edge | record lacking creator, type or collection | Missing lines dropped, no dash or label. No truncation rule for long titles | result_card_component.rb:43-45 | R |
| H11 | Results | Save states | Happy/Edge | click Save | "Save", "Saving...", "Saved"; accessible name "Save record: <title>"; no-JS button "Save"/"Remove"; failure "Sorry, there was a problem saving the record." | en.yml | Both |
| H12 | Results | Saved bar count | Happy | after saving | Header live count "saved record(s)" | saved_bar_component.html.erb | R |
| H13 | Results | Sort menu | Happy | `sort=` | "Sort by relevance" etc. (full label under 768px) | catalog_controller.rb:107-111 | Both |
| H14 | Results | Per-page menu | Happy | `per_page=12|24|40|96` | "40 results per page"; under 576px "40 per page" | blacklight.en.yml:22-24 | Both |
| H15 | Results | View toggle | Happy | List and Mosaic buttons | Tooltips "List view" and "Mosaic view"; selected pressed | _view_type_group.html.erb | Both |
| F1 | Filters | Rail, desktop | Happy | 992px+ | 320px left column; "Search filters"; "Show only" switch "Records with digital assets"; groups Collection details, Creator, Object, Subject / Topic, Copyright & Advisory, Access, Media type | filter_sidebar_component.html.erb | R |
| F2 | Filters | Facet collapsed | Happy | default (all closed even with selections) | Title then placeholder "Select <label>" | facet_field_component.rb:46-52 | R |
| F3 | Filters | Facet with selection | Happy | `f[...][]=` | Count badge on title; summary "Medical History Museum +1" | facet_field_component.rb:58-63 | R |
| F4 | Filters | Facet expanded | Happy | click facet | "Search <label>..." box, value list with counts; selected value is a link "Remove filter <Facet>: <value>" | facet_panel_controller.js | R |
| F5 | Filters | Long list | Edge | >6 or >12 values | "Show all N" / "Show fewer"; typing hides the toggle | facet_panel_controller.js:49-53 | R |
| F6 | Filters | Facet modal | Edge | facet limited to 20 values | "Show more <field>" opens modal with A-Z index | catalog_controller.rb | R |
| F7 | Filters | Range slider + histogram | Happy | production date, creator birth, creator death | Histogram bars (20 to 60 by width); From/To placeholders show data min and max; handles "Earliest year" and "Latest year"; Clear link; track non-linear before 1000 CE | range_slider_controller.js | R |
| F8 | Filters | Slider, no spread | Edge | <2 non-empty bars | No histogram (`no-bars`) | range_slider_controller.js:200 | R |
| F9 | Filters | Histogram fetch fails | Sad | request fails | No histogram; on-screen state not confirmed | range_slider_controller.js:73-76 | R |
| F10 | Filters | Range in URL | Edge | `range[field][begin|end|missing]` | Summary "1850 - Any", "Any - 1900", "Missing" | facet_field_component.rb:68-76 | R |
| F11 | Filters | Digital assets switch | Happy | link | `role=switch` on/off; facet "Digital asset": "With a digital asset" / "Without a digital asset" | filter_sidebar_component.html.erb:18-24 | Both |
| F12 | Filters | "Includes all" filter | Edge | `f_all[...]` from advanced search | One pill per value | constraints_component.rb:28-46 | R |
| P1 | Pills | Applied pills | Happy | any query or filter | "N results for" + removable pills; label "Remove filter <group>: <label>"; Rails has no "Start over" | constraints_component.rb | Both |
| P2 | Pills | Clear all | Happy | any applied filter | "Search filters (3)" with "Clear all" | filter_sidebar_component.html.erb:12-15 | R |
| M1 | Mobile | Filter drawer | Happy | under 992px | "Filters" button with applied-count badge; drawer with title, Close, scrim, focus trap, Esc | filter_toggle_component.html.erb | R |
| M2 | Mobile | Toolbar | Happy | under 768px | Sort and per-page share a row; Filters and view buttons next. Breakpoints 992, 768, 400 | results_toolbar.css:99,253,309 | R |
| M3 | Mobile | Banner | Happy | 768 and under | Restyles; further change at 576px | search_banner.css:21,185,237 | R |
| M4 | Mobile | Static layout | Edge | static widths | Modal becomes full-screen sheet under 640px; sidebar from 960px; modal button "Show N records", "Updating...", "No records match" | search-results.html:1269-1370 | S |
| N1 | Pagination | Middle | Happy | `page=6` of 74 | Previous, `1 ... 4 5 6 7 8 ... 74`, Next; current `aria-current` | _results_pagination.html.erb | Both |
| N2 | Pagination | First / last | Edge | first or last page | Previous or Next unavailable (Static disabled) | search-results.html:1346-1361 | Both |
| N3 | Pagination | One page | Edge | total pages 1 | No pagination (Rails); Static "Showing 1-N records" | _results_pagination.html.erb:2 | Both |
| N4 | Pagination | Mobile | Edge | under 576px | Previous and Next each full-width row | pagination.css:94 | R |
| N5 | Pagination | Range text | Edge | any page | "Showing 41-80 records"; "Showing 0 records" | search-results.html:1397 | S |
| N6 | Pagination | Large counts | Edge | over 999 | "1,234 results", delimited page numbers | kaminari/_page.html.erb | R |
| Z1 | Zero results | Empty state | Sad | no matches | h3 "No results found and no suggestions are available for this search phrase."; "Try removing a filter or broadening your search terms."; button "Clear all filters". Static title "No records match your search" | _zero_results.html.erb:3-6 | Both |
| Z2 | Zero results | Spelling auto-correct | Sad | misspelled query with a collation | Info alert: "No results for X. Showing results for Y instead. Did you mean: a, b?" | spelling_correction_component.html.erb | R |
| Z3 | Zero results | "Did you mean" | Sad | Static; Rails only at 100 or fewer results | Static "Did you mean <word>?" / "Did you mean: ...?" | search-results.html:356,396 | Both |
| Z4 | Results | Smart notices | Edge | static smart search | "No records match your words exactly. Showing N related results instead."; "N records match your words exactly. M related results follow them."; "Showing exact matches only."; tags "Close spelling", "Related meaning" | search-results.html:355-370,1417 | S |
| E1 | Query | Special characters stripped | Edge | `?q=red+blue*` | Flash "Special characters can't be used in a search, so they were removed from your search." | query_rules.rb:14 | R |
| E2 | Query | Only invalid characters | Sad | `?q=***` | Redirect to home; alert "Please enter a valid search string."; JSON 422 | query_rules.rb:13,33-36 | R |
| E3 | Query | Blank search | Edge | `?q=` | Allowed; returns everything | query_rules.rb:6 | R |
| E4 | Query | Advanced clause validation | Sad | invalid `clause[n][query]` | Same rule applied | query_rules.rb:30 | R |
| U1 | Error | Solr down or timeout | Sad | connection refused, invalid request, timeout | HTTP 503 page: h1 "Search is unavailable"; "We could not search the collections just now. Please try again in a few minutes."; links "Back to the home page", "contact the collections team" | unavailable.html.erb | R |
| U2 | Error | Static API offline | Sad | static dev toggle | "API: Fallback (Offline)" or "API: Unavailable, local data" | search-results.html:1315 | S |
| L1 | Loading | Page loader | Happy | first paint up to 15s | Navy cover, spinner, "Loading Cultural Collections Search" | page_loader.css:1-25 | R |
| L2 | Loading | Skeleton | Happy | change slower than 150ms | Tiles, facet values and pills shimmer grey; pagination and toolbar at 50%; `aria-busy`; reduced motion flat grey | search_loading.js; skeleton.css | R |
| L3 | Loading | Static skeleton | Happy | any change (static) | 420ms loading state with placeholder cards, "Loading results" | search-results.html:376-384 | S |
| A1 | Advanced | Page | Happy | `/catalog/advanced` | Banner "Advanced search" / "Combine fields and filters to find exactly what you're looking for across every collection."; Search (rows, "Add row"), Filters ("Add filter"), Dates, "Sort results by"; "Start over", "Search"; Search help sidebar | advanced_search.en.yml | Both |
| A2 | Advanced | Flyout | Happy | "Advanced search" link (XHR) | Same form in a modal, prefilled; static iframe flyout; full width at 576 and under | advanced_flyout.css:91 | Both |
| A3 | Advanced | Row limit | Edge | reaching 8 rows | "You can add up to 8 rows." | advanced_search_form_component.rb:16 | R |
| A4 | Advanced | Empty submit | Sad | search with nothing entered | "There is a problem": "Enter search terms or choose a filter to search." | advanced_search_controller.js:137-143 | R |
| A5 | Advanced | Date order | Sad | From later than To | "<Field>: the From year must not be later than the To year." | same | R |
| A6 | Advanced | Filter with 13+ values | Edge | large filter | "Find in <filter>" box; "No values to choose from" when empty | advanced_search_form_component.html.erb:60 | R |
| A7 | Advanced | Static date errors | Sad | static date field | "<Label> must be a date in the format dd/mm/yyyy, or a year (numbers only)."; "...must be between X and Y, the earliest and latest dates in the collections." | advanced-search-form.js:361-362 | S |
| A8 | Results | Static year errors | Sad | static facet year box | "Enter years as whole numbers, for example 1850 (or -400 for BCE)."; "Enter a year between -5000 and 2100."; "The earliest year can't be after the latest year." | search-results.html:1163-1165 | S |
| H20 | History | Rails | Happy | `/search_history` | h1 "Search History"; day headings; Clear link with confirm; empty "You have no search history" | search_history/index.html.erb | R |
| H21 | History | Static | Happy/Edge | `search-history.html` | "Search history"; "The searches you have made on this browser, newest first. Choose one to run it again. Searches are kept for 30 days."; empty "No searches yet. Searches you make will be listed here." | search-history.html:220-226 | S |
| U10 | URL | Params that change UI | Edge | `q`, `f[]`, `f_inclusive[]`, `f_all[]`, `range[field][begin|end|missing]`, `sort`, `per_page`, `page`, `view`, `clause[n][field|op|query]`, `bins` (8-60). Static also `collection`, `type`, `named`, `classification`, `exact=1`, `scope` | | catalog_controller.rb | Both |
| U11 | Results | Save this search | Edge | static toolbar | "Save this search", then "Saved" for 1.8s | search-results.html:1378 | S |

## Components (code names)
Rails: `SearchBannerComponent`, `HeroSearchComponent`, `SearchOverlayComponent`, `HeaderComponent`, `SavedBarComponent`,
`BreadcrumbComponent`, `ConstraintsComponent`, `ResultCardComponent` (`result-card--media` / `--no-media`), `SaveControlComponent`,
`FilterToggleComponent`, `FilterSidebarComponent`, `FacetFieldComponent`, `FacetItemComponent`, `AdvancedSearchFormComponent`,
`SpellingCorrectionComponent`, partials `_zero_results`, `unavailable`. Stimulus: search-overlay, advanced-flyout,
advanced-search, select-dropdown, filter-drawer, filter-toggle, facet-dropdowns, facet-panel, range-slider, tooltip, saved-bar,
back-to-top. Static: `search-results-*`, `facet-rail__*`, `search-results-pill`.

## Rails vs Static
Sort (Static no Z-A); zero-results title; spelling (Rails auto-retry alert vs Static "Did you mean" plus smart notices); filters
(Rails ~12 facets vs Static ~27 with modal); pagination range text (Static only); errors (Rails 503 + flash vs Static year
errors and API pill); loading (Rails loader + skeleton vs Static 420ms cards); Static-only "Save this search".
Open questions: Rails deep `page=` value; on-screen state when histogram fetch fails.
