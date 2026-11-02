# Architecture

How Collections Navigator (the Rails app in `ead-ccs-test/`) fits together, for a developer who has not seen it before. The
words used for the product are in [CONTEXT.md](../CONTEXT.md); the decisions behind the shape are in [docs/adr](adr/). To make
a particular change, go to [how-to-change.md](how-to-change.md).

## The shape in one paragraph

A Rails 8 app with Blacklight 9 on top of **Solr**, which holds every searchable record (about 41,000). **Postgres** holds only
what a visitor creates: search history, saved records, saved searches, lists and access requests. Nobody logs in: a visitor is
a row keyed by the session cookie. The pages are ViewComponents (`app/components/nexus_ccs/`) and a few views, styled by plain
CSS files imported from one manifest, with Stimulus controllers for the small interactions. There is no background job in use.

```
 browser ──HTTPS──> Rack middleware ──> routes ──> controller ──> model / presenter ──> view + components
                    (BotGuard,                        │                  │
                     compression,                     │                  └──> Solr (read only, via Blacklight)
                     static files)                    └──> Postgres (the visitor's own rows)
```

## The request flow

1. **Middleware** (`config/initializers/bot_guard.rb`, `performance.rb`): `BotGuard` answers 403 to listed crawlers on asset and
   download files, 429 over the per-minute limit, and sets `X-Robots-Tag` on every response. Then compression and the static
   file cache headers, then Rails' own static file server for `public/` (the digital assets are files under
   `public/digital-assets`).
2. **Routes** (`config/routes.rb`): Blacklight's `/catalog` routes (search, record, advanced search, facets), the app's own
   pages (`/`, `/help`, `/about`), the visitor's pages (`/search_history`, and `/bookmarks`, `/saved_searches`, `/lists` only
   when `SAVED_RECORDS=on`), `/access_requests`, the SEO files, the error pages and `/up`.
3. **Controller**: `CatalogController` is Blacklight's, configured in one place (`configure_blacklight`, with the fields and
   facets built from `DataModel` and `app/models/catalog_config/`). Before a results request it asks `SearchDefaults` what to
   do (go home, send the empty advanced form back, or redirect with the "With a digital asset" filter added).
4. **Search**: `SearchService` (a Blacklight service) runs the query through `SearchBuilder`. It retries once with Solr's
   spelling collation when nothing is found, and counts what the filters hide (`ZeroResults`) for the empty page.
5. **Chrome**: `PageChrome.for(...)` decides the breadcrumb trail, the banner under it and where the saved-records bar sits, for
   every page, in one place. `PageMeta` decides the page's description, canonical link and robots directive.
6. **View**: `layouts/application.html.erb` (or `pages.html.erb`, `branded_stock.html.erb`, `stock_blacklight.html.erb`) draws
   `NexusCcs::HeaderComponent`, the page, and `NexusCcs::SiteFooterComponent`.
7. **Errors**: `config.exceptions_app` sends a failed request to `/<status>`, drawn by `ErrorsController` inside the site
   header and footer. If Solr is down, `CatalogController` shows the "search unavailable" page and the other pages keep working.

## The main objects

All are plain Ruby in `app/models/` (or `lib/middleware/`), each with a unit test in `test/models/`. Each file starts with a
comment saying what it decides; read that first.

| Object | Decides | Used by |
|---|---|---|
| `SearchDefaults` | what a results request gets before it is searched: home page, the advanced form again, or the default digital-asset filter ([ADR 0004](adr/0004-results-default-to-records-with-a-digital-asset.md)) | `CatalogController` |
| `PageChrome` | breadcrumbs, banner and saved-bar position for each page | `ApplicationController` helpers, `HeaderComponent` |
| `AccessPolicy` | what a visitor may do with a record's assets (`:open`, `:view_only`, `:request`), from its licence ([ADR 0007](adr/0007-access-policy-is-derived-from-the-licence.md)) | record page, results cards, downloads, SEO |
| `Sensitivity` | whether a record's assets are sensitive, so the visitor is asked first; the visitor's choice lives in the session | record page, `BulkDownload`, SEO |
| `BotGuard` (`lib/middleware`), `BotControls`, `RobotsPolicy` | crawler blocks, rate limits ([ADR 0010](adr/0010-bot-guard-rate-limits-are-in-memory.md)) and what search engines may index | every request |
| `BulkDownload`, `ZipWriter` | which selected records' files go into one zip, which are left out and why; nothing is zipped before the visitor has seen the plan | `BulkDownloadsController` |
| `Citation` | APA, MLA, Chicago and Harvard citations for a record | citation pages and modals |
| `SearchHistoryDays` | groups search history by Melbourne day | `/search_history` |
| `List`, `ListItem`, `SavedSearch`, `User` | the visitor's lists and saved searches; `User` is the guest row ([ADR 0008](adr/0008-guest-users-without-login.md)) | `/lists`, `/saved_searches`, `/bookmarks` |
| `DataModel` | the record fields and filters from the two project workbooks and `config/data_model/solr_mapping.yml` | `CatalogController`, `test/models/data_model_test.rb` |
| `Sitemap`, `CanonicalUrl`, `StructuredData`, `RobotsTxt` | the SEO files and tags ([seo-and-bot-controls.md](../ead-ccs-test/docs/seo-and-bot-controls.md)) | `SeoController`, `layouts/_seo_head` |

## Solr and Postgres

| | Solr | Postgres |
|---|---|---|
| Holds | one core, `blacklight-core`: the records, their facets and the spelling dictionary | `users`, `searches`, `bookmarks`, `saved_searches`, `lists`, `list_items`, `access_requests` |
| Written by | the **indexing**, never by the web app while it serves visitors ([ADR 0011](adr/0011-solr-is-read-only-for-the-app.md)) | the app, on a visitor's action |
| Lost if emptied | the index is rebuilt from the exports (below) | a visitor's saved items; nothing else |
| Schema | `ead-ccs-test/solr/conf/schema.xml` and `solrconfig.xml` (the dev team's) | `db/schema.rb`, changed only by a migration |

Nothing is ever written to a record from the site. A request for access (`AccessRequest`) is stored in Postgres and listed by
`bin/rails access_requests:export` (CSV on screen) for staff to action; the app sends no email.

## Where the records come from

What is known from this repository and the index (the University dev team's own ingest is not here):

- Two collection management systems export CSV: **EMu** (Museums & Collections) and **Vernon** (the Medical History
  Museum's system, MDHS). `ead-ccs-test/data/emu.csv` and `vernon.csv` are committed copies. The five collections shown to
  visitors are values of the `collection_ssim` field, listed in `config/pages.yml`.
- `Collections::Indexer` with `EmuSource` and `VernonSource` (`app/indexers/collections/`) turns each row into a Solr document
  and posts it. `bin/rails collections:index` runs it (it skips a core that already holds records unless `FORCE=1`). It is
  how development, CI and the Azure demo fill Solr (`AUTO_INDEX=true` does it on start where Solr has no disk of its own).
- The University's real ingest also writes the digital asset metadata from the DAM into the Solr field `assets_json`. The
  app does not read it yet: `AccessPolicy` and `Sensitivity` use the licence and restriction notes as stand-ins, and each says
  in its header which rules to replace when the DAM's own classification arrives.
- Asset addresses come from `config/digital_assets.yml` and `config/digital_media.yml`, by `Collections::DigitalAssets` and
  `DigitalMedia`; the files themselves are under `public/digital-assets`.
- The record ids start with the source system (`emu-9044`, `vernon-MHM00394`), which is how the code tells them apart.

## Configuration

Everything configurable is an environment variable. The full list, with defaults, is in
[configuration.md](configuration.md), and `script/check_docs.rb` fails if the code reads a variable that table does not list.
Feature flags (`SAVED_RECORDS`, `SEO_INDEXING`, `SEO_LLMS_TXT`, `BOT_CONTROLS`, `RATE_LIMIT`...) are in the same file. Fixed
content lives in YAML: `config/pages.yml` (collections and their text), `config/ai_crawlers.yml` (user agents),
`config/data_model/` (the workbooks' fields and filters), `config/locales/` (every sentence a visitor reads).

## The front end

- **CSS**: `app/assets/stylesheets/application.css` is the one manifest; add a file with an `@import` line there. Tokens are in
  `tokens/`, one file per component in `components/`, one per page in `pages/`. At build time `lib/asset_bundle.rb` flattens the
  imports into one file. [styling.md](../ead-ccs-test/docs/styling.md) has the rules.
- **JavaScript**: importmap (no bundler). Stimulus controllers in `app/javascript/controllers/` load themselves by file name.
  OpenSeadragon, Bootstrap and the range chart are vendored in `vendor/javascript/`.
- **Components**: `NexusCcs::*` ViewComponents in `app/components/nexus_ccs/`, tested in `test/components/`.

## Tests, and how they are laid out

`bin/rails test` (about 640 tests, 12 seconds) is the unit and integration suite; `bin/rails test:system` runs the browser
journeys and the axe accessibility checks and needs Solr. `bin/ci` runs everything GitHub runs. See
[CONTRIBUTING.md](../CONTRIBUTING.md).
