# Performance (CCS-71, BR-18.04)

> As the Nexus CCS, I want to respond quickly and operate efficiently so that users have a smooth and seamless search experience.

The story has no numbers, so this page sets them. It has four parts: a plain summary, the budgets, the details of what was
measured and changed, and what the app cannot do on its own.

## In plain language

**What we did.** We timed the main pages as a visitor's browser sees them (on a simulated mid-range phone with a good 4G
connection), found what was slowing them down, fixed what could be fixed inside the app, and put checks in the automatic tests
so the pages cannot quietly get slower again.

**What was slowing the site down.**

1. The app sent every page uncompressed. Nothing in the container compresses (it runs Puma directly; Thruster is installed but is not started).
2. The stylesheet was not one file but a list of 48 more files fetched one after another before anything could be drawn.
3. Every page downloaded a 277 kB picture-viewer library that only the two stock record pages use.
4. The home page loaded five collection photos of 450-500 kB each (2 MB in all) where 100 kB each is enough.
5. A few pages ran database queries they did not need.

**How much faster it is.** Measured on one machine, in production mode, against the real 40,962-record Solr index:

| | Before | After |
| --- | --- | --- |
| Data a visitor downloads for a results page | 1.78 MB | 0.49 MB (73% less) |
| Data for the home page | 3.9 MB | 0.67 MB (83% less) |
| Requests the browser makes per page | 121 | 66 |
| Time until the page first shows something (simulated phone) | 2.2 s | 0.5 s |
| Time until the main content is shown, home page | 4.2 s | 2.1 s |
| Time until the main content is shown, record page | 4.1 s | 2.1 s |
| Time the server takes to build a results page | about 30 ms | about 30 ms (unchanged: it was never the problem) |

The server was already fast. Almost all the time was spent sending and drawing the page, and that is what changed.

**What the budgets are.** The page you see should be there in 2.5 seconds or less on a mid-range phone, should not jump about
as it loads (0.1 or less), and should respond to a tap within 200 ms. These are Google's "good" limits for the Core Web Vitals.
Behind them are smaller limits for the server, Solr requests, database queries and page weight. The table below says which
limits are tested automatically.

**What the app cannot do by itself.** A content delivery network (CDN) for the record images, HTTP/2 or HTTP/3, automatic
scaling, and the size of the Solr and database servers are hosting decisions. They are listed at the end as recommendations.

**One finding that needs a design decision.** The "Loading Collections Navigator" cover stays up until the browser has finished
loading every image and script (the window's `load` event). So the time a visitor waits is the time to load everything, not the
time to first content. It was not changed because it is a design choice; see "Not changed" below.

## Budgets

Two kinds of number. **Target** is a limit we choose, from common guidance or judgement. **Measured** is what the pages did on
2-3 Nov 2026 on a developer laptop (production mode, Rails and Solr on the same machine), so it is only a baseline: real hosting
adds network time to Solr and the database, and the figures must be re-measured there (`bin/perf`).

| Measure | Budget (target) | Measured now | Why this number | Checked by |
| --- | --- | --- | --- | --- |
| Largest Contentful Paint | 2.5 s or less | 2.1 s (home, results, record; simulated phone) | Core Web Vitals "good" | `bin/perf browser` (by hand) |
| Cumulative Layout Shift | 0.1 or less | 0.00-0.05 on most pages; 0.094 record page with two images; 0.14 mosaic with thumbnails (test machine) | Core Web Vitals "good" | system test (list view 0.1; mosaic held at 0.25 while it is above target) |
| Interaction to Next Paint | 200 ms or less | not measurable by script; total blocking time 0 ms on most pages, 20 ms on Advanced search | Core Web Vitals "good"; blocking time is a stand-in | `bin/perf browser` (by hand) |
| Server response, home / help / about | p95 50 ms | p50 7-9 ms, p95 14-16 ms | about 3x the measured value, since a hosted machine is slower than this laptop | by hand |
| Server response, results page | p95 150 ms | p50 27 ms, p95 49 ms before CCS-39; highlighting adds about 20 ms to the Solr request for a common word on 40 results (skull: 4.6 to 23 ms), so expect p95 near 70 ms | as above; it makes two Solr requests (highlighting rides on the first, no extra request). A search that finds nothing or few records makes one more per filter, at most 8 (CCS-43) | by hand |
| Server response, record page | p95 100 ms | p50 18 ms, p95 31 ms | one Solr request | by hand |
| Server response, Advanced search | p95 300 ms | p50 77 ms, p95 115 ms | one Solr request that asks for up to 100 values of each filter | by hand |
| Solr requests per page | results 2, record 1, every other page 0 | the same | the header's collection counts are cached for a day (`BrowseMenu`) | `PerformanceTest` (needs Solr) |
| Database queries per page | home, help, about 1; lists and saved searches 3 (however many are saved); search history 2; results 4; record 6 | 1 / 3 / 3 / 2 / 3 / 6 | the measured count; a rise means a new query or an N+1 | `PerformanceTest` |
| HTML size, home / help / about | 56 / 56 / 50 kB, 14 kB compressed | 46 / 45 / 39 kB, 9.7 kB compressed | measured plus about 20% | `PerformanceTest` |
| HTML size, Advanced search | 480 kB, 40 kB compressed | 442 kB, 32 kB compressed | measured; large because it lists up to 100 values per filter. A target to reduce | by hand |
| Stylesheets | 1 request, 100 kB compressed or less | 1 request, 85.8 kB | one request is the point of the bundle | `PerformanceTest` (one stylesheet link) |
| Scripts | 2 script tags, 230 kB compressed or less | 2, 206 kB | measured plus about 10% | `PerformanceTest` (script tags, modulepreload list) |
| Page weight over the wire, no photographs | 550 kB or less | 485 kB | measured plus about 10% | by hand |
| Requests per page, no photographs | 70 or less | 66 | the rate limit counts every request (600 asset requests a minute per address) | by hand |

Raise a budget only with a reason, and change this page and the test together.

## What was measured

`bin/perf` repeats every measurement (see "Reproducing it"). The browser figures use headless Chrome through the DevTools
protocol, slowed to a mid-range phone: 4x CPU slowdown, 9 Mbit/s down, 170 ms round trip, 412 x 915 pixel screen, a fresh
browser profile for every load (nothing cached), the median of 3 loads before and 5 after. Lighthouse's own mobile profile is
slower (1.6 Mbit/s) and would show larger numbers for the same pages.

### Browser, before and after

"Wire" is bytes transferred; "plain" is the bytes after unpacking. Before the changes the two were equal because nothing was compressed.

| Page | FCP before | FCP after | LCP before | LCP after | Wire kB before | Wire kB after | Requests before | after | CSS requests before | after |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Home | 2212 | 524 | 4152 | 2076 | 3913 | 675 | 128 | 68 | 48 | 1 |
| Help | 2212 | 528 | 2212 | 528 | 1772 | 487 | 121 | 66 | 48 | 1 |
| About | 2232 | 520 | 2232 | 520 | 1766 | 485 | 121 | 66 | 48 | 1 |
| Results, list (q=skull) | 2428 | 704 | 4116 | 2164 | 1780 | 486 | 121 | 66 | 48 | 1 |
| Results, mosaic (q=skull) | 2396 | 712 | 4104 | 2156 | 1780 | 486 | 121 | 66 | 48 | 1 |
| Results with a filter | 2416 | 704 | 2416 | 704 | 1783 | 487 | 121 | 66 | 48 | 1 |
| Record emu-406126 | 2220 | 528 | 4068 | 2132 | 1953 | 652 | 122 | 67 | 48 | 1 |
| Record emu-20335 | 2220 | 524 | 4200 | 2272 | 2105 | 803 | 123 | 68 | 48 | 1 |
| Advanced search | 2344 | 672 | 2344 | 672 | 2160 | 508 | 121 | 66 | 48 | 1 |
| Search history | 2200 | 508 | 2200 | 508 | 1759 | 484 | 121 | 66 | 48 | 1 |
| Lists | 2216 | 516 | 2216 | 516 | 1759 | 484 | 121 | 66 | 48 | 1 |
| Saved searches | 2212 | 508 | 2212 | 508 | 1759 | 484 | 121 | 66 | 48 | 1 |
| Saved records | 2208 | 508 | 2208 | 508 | 1759 | 484 | 121 | 66 | 48 | 1 |

Times are milliseconds. CSS, JS and image bytes on the wire, per page:

| | Before | After |
| --- | --- | --- |
| CSS | 505 kB in 48 requests | 86 kB in 1 request |
| JavaScript | 922 kB | 206 kB |
| Home page images | 2,344 kB | 279 kB |
| Fonts, icons and the logo | included above | included above |

Notes on reading these:

- **FCP** (first contentful paint) is the "Loading Collections Navigator" cover; the content comes when the cover comes off, at the
  window's `load` event, which is what **LCP** shows on pages with an image or the main heading. Where LCP equals FCP, the main
  content was the first thing painted.
- Time to first byte (TTFB) was 11-270 ms; results pages are the slowest because they wait for Solr (both before and after).
- The lists, saved searches and saved records pages were measured for a visitor with nothing saved (the browser has no cookie).
  The database figures below use a visitor with two lists, five records, and two saved searches.
- Layout shift on Record emu-20335 stays at 0.094. In a separate trace in the test browser the only shifts on that page were a
  withheld-access notice being removed and the header settling (0.016); the larger figure appears only under the CPU slowdown.
  It is below the 0.1 limit but close.

### Server, database and Solr, before and after

Built in process by `bin/perf counts` (production mode, warm, median of 7-9 requests). "ms" is the whole Rails request,
including the Solr round trip.

| Page | ms before | ms after | SQL before | SQL after | Solr requests | HTML kB | HTML kB gzipped |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Home | 5 | 6 | 1 | 1 | 0 | 46 | 8.9 |
| Help | 4 | 6 | 1 | 1 | 0 | 45 | 9.4 |
| About | 7 | 5 | 1 | 1 | 0 | 39 | 8.3 |
| Results, list | 28 | 39 | 3 | 3 | 2 | 53 | 9.3 |
| Results, mosaic | 28 | 33 | 3 | 3 | 2 | 53 | 9.3 |
| Results with a filter | 31 | 28 | 3 | 3 | 2 | 56 | 9.6 |
| Record emu-406126 | 15 | 20 | 6 | 6 | 1 | 65 | 12.5 |
| Record emu-20335 | 16 | 37 | 6 | 6 | 1 | 67 | 12.7 |
| Advanced search | 74 | 82 | 1 | 1 | 1 | 442 | 31.6 |
| Search history | 13 | 15 | 2 | 2 | 0 | 59 | 8.4 |
| Lists | 9 | 9 | **5** | **3** | 0 | 36 | 7.6 |
| Saved searches | 5 | 7 | 3 | 3 | 0 | 37 | 7.4 |
| Saved records | 20 | 22 | 6 | 6 | 1 | 45 | 8.7 |

The "ms" columns before and after differ by run-to-run noise on a shared laptop (Solr and Chrome were also running); the server
cost did not change and was not the bottleneck. The one real database saving is the lists page (5 queries to 3). The
Solr counts are the same before and after: the results page asks twice (the page of results, and a second request that counts
the records in the other half of the "with a digital asset" filter), the record page once, the others not at all.

The header's "Search collections" counts (`BrowseMenu`) are one Solr request, cached for a day; they were already cached.
Solr's own response for a page of 40 results is 34 kB, so listing fields (`fl`) would save little and was not changed.

### Database

All the guest-user tables already have the indexes their queries use, so no migration was added:

| Table | Indexes | Used by |
| --- | --- | --- |
| `lists` | `user_id`; unique `user_id, lower(name)` | the lists page and its limit |
| `list_items` | `list_id`; unique `list_id, document_id` | a list's records; adding the same record twice |
| `saved_searches` | `user_id` | the saved searches page |
| `bookmarks` | `user_id`; `document_id` | the saved records count (every page) and page |
| `searches` | `user_id` | search history (read by id from the session) |
| `access_requests` | `document_id`; `status` | the export |

The connection pool (`max_connections`) equals `RAILS_MAX_THREADS` (5 if unset) and Puma's thread count is
`RAILS_MAX_THREADS` (3 if unset), so a thread never waits for a connection. Set the same `RAILS_MAX_THREADS` for both when
changing it. Each page's queries add up to a few milliseconds, so the database is not a limit at this size.

## What was changed

All inside the app, with no new gems and no new importmap pins.

| Change | Files | Effect |
| --- | --- | --- |
| **Gzip for HTML, CSS, JavaScript, JSON, SVG and text** (`Rack::Deflater`, over 1 kB, text types only) | `config/initializers/performance.rb` | HTML 46 kB to 9.7 kB. The container's CMD is `rails server` (Puma), so nothing else compressed. A CDN or reverse proxy in front sees `Content-Encoding` already set and leaves it alone |
| **One stylesheet** instead of 49: after `assets:precompile`, the 48 `@import` lines of `application.css` and `stock_blacklight.css` are replaced by the files' content, in the same order. Every address inside is already fingerprinted, so the CSS is unchanged | `lib/asset_bundle.rb`, `lib/tasks/asset_bundle.rake`; the Dockerfile's existing `assets:precompile` runs it | 48 requests removed, and the wait for the browser to read the first file before it can start the other 48. Development and test still serve the separate files, so editing CSS is unchanged |
| **Gzipped copies of the assets** written beside the originals (`name.css.gz`) | same | `ActionDispatch::Static` serves them with no compression work per request: CSS 500 kB to 86 kB, JS to 206 kB |
| **Cache lifetimes by kind of file**: fingerprinted `/assets` for a year and `immutable`; the records' images (`/digital-assets`) for a year at an address with a version token and revalidated at any other (CCS-425, [media-refresh.md](media-refresh.md); this was a day); other public files (icons, error pages) for an hour. Before, every file in `public/` was cached for a year | `lib/middleware/static_cache_control.rb`, `config/initializers/performance.rb`, `config/environments/production.rb` | repeat visitors fetch none of the assets again; the unfingerprinted images and icons can no longer be stale for a year after they change |
| **The OpenSeadragon viewer preloaded only on the two stock record pages** (`preload:` names the entry point) | `config/importmap.rb` | 277 kB of script no longer downloaded on every other page; the stock pages still preload it |
| **Home page images**: five collection photos re-encoded from 2000 px / 450-500 kB to 1100 px / 90-170 kB; banner from 188 kB to 102 kB; `width`, `height`, `loading="lazy"`, `decoding="async"` on the cards; `fetchpriority="high"` on the banner | `app/views/pages/home.html.erb`, `app/assets/images/site/*` (**shared template and assets**) | home page 2.3 MB of images to 0.28 MB; the cards hold their space while they load |
| **Record page main image**: `fetchpriority="high"`, `decoding="async"`, and `width`/`height` read from the file so the browser holds its space; `width: auto` in the stylesheet keeps the layout as it was | `app/components/nexus_ccs/digital_assets_component.*`, `lib/image_dimensions.rb`, `app/assets/stylesheets/components/digital_assets.css` (**shared component and CSS**) | it is the largest thing on the page, so it is fetched first |
| **Result card thumbnails**: `decoding="async"` and `width`/`height` (they were already lazy) | `app/components/nexus_ccs/result_card_component.*` (**shared component**) | the mosaic's layout shift on a results page with thumbnails fell from 0.30 to 0.14 |
| **Lists page**: the lists are loaded once, so counting and checking for none cost no more queries | `app/controllers/lists_controller.rb` | 5 queries to 3 |
| **`bin/perf`** reproduces the measurements; `test/support/request_counter.rb` counts SQL and Solr requests | `bin/perf`, `test/support/request_counter.rb` | not run in CI |

Security notes: compressing HTML that carries a CSRF token can leak the token (the BREACH attack), but Rails masks the token
differently on every response, so two responses never compress alike. Personal pages were not given any cache header.

Runtime behaviour that is different in production: responses are gzipped for browsers that ask for it; static files have the
lifetimes above; the first request after a deploy to a new asset address fetches one stylesheet instead of 49; the OpenSeadragon
library is fetched only when a stock record page is opened.

### Guarded by tests

`test/integration/performance_test.rb` (runs without Solr; the Solr tests skip themselves):

- gzip on HTML, and none on images;
- the Cache-Control of fingerprinted assets, the records' images and other public files, and that a private or uncacheable response is never given a lifetime;
- **no page that sets a cookie, and no personal page, is ever publicly cacheable** (home, help, about, lists, a list, saved searches, search history, access request, saved records);
- HTML size budgets for home, help and about; one stylesheet and at most two scripts per page; the viewer not preloaded outside the stock pages;
- database queries: the lists page (3, and the same for 1 list or 6: an N+1 fails), saved searches (3, the same for 1 search or 9), none for a visitor with no guest row, static pages at most 1 and no Solr;
- with Solr: a results page (2 Solr requests, 4 queries), a record page (1 Solr request, 6 queries), and the main image's `fetchpriority`, `decoding` and size.

`test/lib/asset_bundle_test.rb` and `test/lib/image_dimensions_test.rb` cover the bundler and the size reader.
`test/system/performance_markup_test.rb` (needs Solr and Chrome) checks the LCP and CLS markup in a real browser: the record page's
main image is high priority and sized to match the file, thumbnails wait, the home banner is high priority, the cards are lazy
and sized, and the layout shift of the record page, home page and list view stays at 0.1 or below (the mosaic at 0.25).

## Not changed, and why

| Finding | Why it was left | Suggestion |
| --- | --- | --- |
| **The loading cover waits for the window `load` event** (`app/javascript/page_loader.js`, `components/page_loader.css`). The visitor sees a navy "Loading" screen until every script and visible image has finished. This is why LCP is about 2.1 s when the first paint is 0.5 s | A design decision, not a bug | Take the cover off at `DOMContentLoaded`, or after first paint, instead of `load`. It would roughly halve the wait on a slow connection. Needs a check that nothing jumps when the CSS and fonts arrive |
| **Home, help and about are not publicly cacheable.** Their responses set a session cookie and carry a per-visitor CSRF token and script nonce, so the ETag changes on every response (no `304`) and `Cache-Control: public` would let a shared cache hand one visitor's token to another | Unsafe without changing sessions and the Content Security Policy | If a CDN is added, strip `Set-Cookie` for these three paths there, and serve them without the token (they have no forms that post) |
| **Chart.js (200 kB, about 67 kB compressed) loads on every page** because the range-limit script statically imports it, so it cannot be left off the pages without a chart | It belongs to the search and filter code (`blacklight-range-limit`), owned by the dev team | Load the range-limit script only on pages with a year filter |
| **Advanced search is 442 kB of HTML** (32 kB compressed): up to 100 values for each of 14 filters | Search behaviour and facets belong to the dev team | Fewer values per filter, or load the lists when a filter is opened |
| **The results page makes two Solr requests**, and every request asks Solr for spellcheck suggestions | `SearchBuilder`, `SearchDefaults` and the Solr config are the dev team's | Measure the second request's cost on the hosted Solr before removing it |
| **The mosaic (default view) shifts 0.14** when thumbnails are present: the gallery script places the cards after the page paints, and the filters panel opens its sections | Blacklight-gallery's behaviour | Reserve the mosaic's height, or lay it out with CSS only |
| **Result thumbnails are 640 px wide** (up to about 150 kB) for a card about 240 px wide | The thumbnails are made by the data pipeline | Make 320 px thumbnails for cards (`image_processing` is installed but variants are disabled) |
| **Logo SVGs are 87-89 kB each** (`logo-header-*.svg`, `uom-logo-vert-ondark.svg`) | University brand files; gzip already takes them to a fraction | Optimise the SVGs with the brand team |

## Reproducing it

```sh
cd ead-ccs-test
export DB_SUFFIX=_perf SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core
export POSTGRES_HOST=localhost POSTGRES_DB=ead_ccs_perf_prod POSTGRES_USER=$USER SECRET_KEY_BASE=dummy RAILS_HOSTS=localhost SAVED_RECORDS=on
RAILS_ENV=production bin/rails db:prepare assets:precompile
RAILS_ENV=production RAILS_SERVE_STATIC_FILES=1 bin/rails server -p 3027 &

RAILS_ENV=production RAILS_LOG_LEVEL=error bin/perf counts       # SQL, Solr requests, HTML size, server time (in process)
RAILS_ENV=production bin/perf browser http://localhost:3027      # requests, bytes, FCP, LCP, CLS, blocking time (headless Chrome)
```

Add paths as arguments to measure other pages. `PERF_RUNS` (default 5) sets the loads per page; `PERF_SQL=1` lists the queries;
`PERF_LATENCY` and `PERF_DOWN_KBPS` change the simulated network. Measure on the hosted environment for real figures.
`bin/perf` needs the Solr core and Chrome, so it is not run in CI.

What could not be measured: Interaction to Next Paint (it needs real taps; total blocking time is reported in its place);
behaviour with the hosted network, Solr and database; the effect of a CDN; load with many visitors at once (the shared Solr was
kept to a modest load).

## What needs a hosting decision

None of these can be done in the app. They are recommendations; the app was left neutral about the host.

1. **A CDN in front of the site**, mainly for `/digital-assets` (42 MB of large images and 12 MB of thumbnails in the repository,
   up to 630 kB each) and `/assets`. The app already sends the right lifetimes (`public`, a day for images, a year and
   `immutable` for assets). With a CDN: serve images in modern formats (AVIF/WebP) and at the size the card needs; add Brotli
   (about 15-20% smaller than gzip); strip cookies on static paths.
2. **HTTP/2 or HTTP/3** at the edge or ingress. Puma speaks HTTP/1.1 only. The one-stylesheet change removed most of the
   cost of HTTP/1.1, but HTTP/2 helps the 60 remaining small requests.
3. **A shared cache store.** `Rails.cache` is the default file store in production, one per container, so the header's collection
   counts and the sitemap are fetched once per container, and the bot-guard rate limit is counted per container. Use `solid_cache`
   (already in the Gemfile) or Redis for one count across instances (`RATE_LIMIT_STORE=cache`).
4. **Scaling.** One Puma process has 3 threads. Run more instances rather than more threads (the pool matches the thread
   count), or set `WEB_CONCURRENCY` for forked workers; set a minimum of 2 instances so a deploy or a restart is not seen by visitors.
   Set autoscaling on request concurrency, not only CPU, since search time is spent waiting for Solr.
5. **Solr sizing and caching.** All search time is Solr. Give it memory for the index to stay in the OS cache; consider a
   query-result cache (`queryResultCache` and `filterCache` in `solrconfig.xml`, which the dev team owns) and running Solr close to the app (same
   region, same network). The Solr timeout is 20 s (`config/blacklight.yml`); a lower one (3-5 s) makes a slow Solr fail into the "search unavailable" page sooner.
6. **Database sizing.** The guest-user tables are small and indexed; a small managed PostgreSQL is enough. Check that the
   connection limit is at least instances x `RAILS_MAX_THREADS`.
7. **Health and monitoring.** Record real-user Core Web Vitals (Application Insights, or a CDN's analytics) and the server's
   p95 per route; the budgets here come from one laptop, and these would replace them with field data.
8. **Compression at the edge.** If the host or CDN compresses, the app's `Rack::Deflater` can stay: it does nothing to a response
   that is already encoded.
