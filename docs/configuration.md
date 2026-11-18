# Configuration: environment variables and feature flags

Every environment variable the app reads, in one table. `ruby script/check_docs.rb` (run by `bin/ci`) fails if the code reads a
variable that is not in the first column below, so add a row in the same change that adds the variable. Secrets are never
written in a file or a pull request: production values are Azure Container Apps secrets (see
[../infra/azure/README.md](../infra/azure/README.md)).

A switch is **on** only for the word `on` (any case); anything else, or unset, takes the default shown.

## Feature flags

| Flag | Default | Turns on or off | Decision |
|---|---|---|---|
| `SAVED_RECORDS` | off | Save buttons, the saved bar, `/bookmarks`, `/saved_searches`, `/lists` and bulk download (a 404 while off) | [ADR 0005](adr/0005-saved-records-hidden-by-default.md) |
| `SEO_INDEXING` | on in production, off elsewhere | Whether search engines may index the site; off makes every page `noindex, nofollow` | [seo-and-bot-controls.md](../ead-ccs-test/docs/seo-and-bot-controls.md) |
| `SEO_LLMS_TXT` | off | `/llms.txt`; its rights wording is a placeholder awaiting approval | same |
| `BOT_CONTROLS` | on | Crawler disallow rules in `robots.txt`, 403s for listed crawlers, `noai` tags | same |
| `BOT_BLOCK_AI_RETRIEVAL` | off | Also blocks AI answer-engine crawlers, not only training and scraping ones | same |
| `RATE_LIMIT` | on, except in tests | The per-IP, per-minute request limit | [ADR 0010](adr/0010-bot-guard-rate-limits-are-in-memory.md) |
| `AUTO_INDEX` | off (`true` on Azure) | The container fills an empty Solr core from the bundled CSV files on start | [architecture.md](architecture.md) |

## Every variable

| Variable | Default | Read in | Meaning |
|---|---|---|---|
| `SOLR_URL` | `http://127.0.0.1:8983/solr/blacklight-core` | `config/blacklight.yml`, `Collections::Indexer` | The Solr core, with credentials if it needs them. Tests that read Solr skip themselves when it cannot be reached |
| `SECRET_KEY_BASE` | none (required in production) | Rails | Signs the session cookie. Set as a secret; `SECRET_KEY_BASE_DUMMY=1` is used only to precompile assets in the Dockerfile |
| `POSTGRES_HOST` | `postgres` | `config/database.yml` (production) | Database host |
| `POSTGRES_PORT` | `5432` | same | Database port |
| `POSTGRES_DB` | `ead_ccs` | same | Database name |
| `POSTGRES_USER` | `ead_ccs` | same | Database user |
| `POSTGRES_PASSWORD` | none | same | Database password (a secret) |
| `DB_SUFFIX` | empty | `config/database.yml` (development, test) | Appended to the database names, so a second checkout or worktree has databases of its own: `DB_SUFFIX=_2` |
| `EMBED_FRAME_ANCESTORS` | unset (any site) | `app/models/embed_policy.rb` | Which sites may frame the embed pages (`/embed/*`, the only framable pages). Unset or `*`: any site, because embeds show only what any visitor may see. Otherwise origins separated by spaces or commas, e.g. `https://museum.example.org https://*.example.edu`; the site itself is always allowed and anything that is not a plain origin is ignored |
| `RAILS_ASSUME_SSL` | false | `config/environments/production.rb` | `true` when a proxy ends HTTPS in front of the app |
| `RAILS_FORCE_SSL` | false | same | `true` redirects HTTP to HTTPS and sets HSTS |
| `RAILS_HOSTS` | none | same | Comma-separated host names the app answers to (Rails host authorisation) |
| `RAILS_LOG_LEVEL` | `info` | same | Production log level |
| `RAILS_MAX_THREADS` | `3` (Puma), `5` (database pool) | `config/puma.rb`, `config/database.yml` | Threads per Puma process; keep the pool at least as large |
| `WEB_CONCURRENCY` | unset | `config/puma.rb` | Puma worker processes. More than one process makes the in-memory rate limit per process |
| `CACHE_WARM` | on | `config/puma.rb`, `CacheWarmer` | `off` stops the server loading the home, Browse, category, explore, theme and story pages itself after it starts and every few minutes, so their cached parts are ready before a visitor asks (the home page needs 53 Solr requests and Browse 85 on an empty cache) |
| `CACHE_WARM_MINUTES` | `10` | `CacheWarmer` | How often those pages are loaded again (1 to 1440), so a cached part that expires is rebuilt by the server rather than by a visitor |
| `PORT` | `3000` | `config/puma.rb` | The port Puma listens on |
| `PIDFILE` | unset | `config/puma.rb` | Puma pid file |
| `SOLID_QUEUE_IN_PUMA` | unset | `config/puma.rb`, `config/application.rb` | `1` runs Solid Queue inside Puma and sends jobs to it: the DAM sync's recurring jobs (`config/recurring.yml`). See [dam-sync.md](../ead-ccs-test/docs/dam-sync.md) |
| `JOB_CONCURRENCY` | `1` | `config/queue.yml` | Solid Queue worker processes |
| `DAM_API_TOKEN` | unset | `Dam::Client` | The Nexus DAM (Acquia DAM) API token. Never in a file: read from the macOS Keychain when the server or task starts. Unset: the DAM sync does nothing. See [dam-sync.md](../ead-ccs-test/docs/dam-sync.md) |
| `DAM_API_URL` | `https://api.widencollective.com/v2` | `Dam::Client` | The DAM API's address |
| `DAM_SOLR_URL` | unset | `Dam::SolrWriter`, `dam:*` tasks, `WritableCore` (`colour:*`, `index:normalise`) | The Solr core the DAM sync, the colour tasks and the filter clean-up write to: a core of its own (never port 8984, the shared Solr). Unset: they write nothing and stop with a message. See [colour-and-clean-up.md](../ead-ccs-test/docs/colour-and-clean-up.md) |
| `DAM_SYNC_EPOCH` | `2010-01-01T00:00:00Z` | `Dam::Sync.epoch` | A full sync reads everything last edited before this in one window, then a month at a time |
| `FULL` | unset | `dam:sync` | `1` reads every DAM asset (resuming a stopped full run) instead of only what changed |
| `FRESH` | unset | `dam:sync`, `colour:extract` | With `FULL=1`, starts again from the beginning instead of resuming. For `colour:extract`, works out every record's colours again instead of skipping those done |
| `LIMIT` | unset | `colour:extract` | Stops after this many images (to try it on a few) |
| `COLOUR_RATE` | `4` | `Colour::Extractor` | At most this many image requests a second to the DAM during `colour:extract` |
| `COLOUR_IMAGE_HOSTS` | `unimelbourne.widen.net` | `Colour::Fetcher` | The hosts `colour:extract` may download thumbnails from (https only, comma-separated). The site's own `/digital-assets/` files are always read from disk |
| `FROM` | `SOLR_URL` | `dam:copy_index` | The core copied from (only read) |
| `TO` | `DAM_SOLR_URL` | `dam:copy_index` | The core copied into |
| `OUT` | `tmp/dam_unmatched.csv` | `dam:report` | Where the list of DAM assets that match no record is written |
| `DRY_RUN` | unset | `geo:geocode` | `1` counts the places that would be looked up and changes nothing. See [time-and-place.md](../ead-ccs-test/docs/time-and-place.md) |
| `LIMIT` | unset | `geo:geocode` | Stop after this many lookups (a test run); the next run carries on |
| `GEOCODER_URL` | `https://nominatim.openstreetmap.org/search` | `Geo::Nominatim` | The Nominatim search address `geo:geocode` asks. Only the place text is sent |
| `GEOCODER_USER_AGENT` | `CollectionsNavigator-PlaceGeocoder/1.0 (...)` | `Geo::Nominatim` | The User-Agent sent to Nominatim: names the application, never a person or email address |
| `MAP_TILE_URL` | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | `Explore::MapTiles` | The Explore by place map's tile server, fetched by the visitor's browser only after they press "Show the map". Its host is added to the Content Security Policy. Production should name a service the University has an agreement with |
| `MAP_TILE_ATTRIBUTION` | the OpenStreetMap credit | `Explore::MapTiles` | The tile provider's required credit (HTML, links only), shown on and under the map |
| `REDIS_URL` | `redis://localhost:6379/1` | `config/cable.yml` | Action Cable; unused, the app has no cable channel |
| `CCS_MEDIA_BASE_URL` | `/digital-assets/media` | `Collections::DigitalMedia` | Where the audio, video and PDF files are served from |
| `SEO_CANONICAL_BASE_URL` | the request's own address | `BotControls.base_url` | The site's address in canonical links, the sitemap and structured data, when a proxy hides the real host |
| `SUPPRESSED_RECORDS_CACHE_SECONDS` | `30` | `SuppressedRecord` | How long a running server keeps the list of removed records in memory before reading the database again: a removal reaches every instance within this time. See [remove-a-record.md](../ead-ccs-test/docs/remove-a-record.md) |
| `INDEX` | unset | `records:csv_to_documents` | `1` also indexes the converted CSV into the core at `SOLR_URL` (never port 8984, the shared Solr). See [csv-upload.md](../ead-ccs-test/docs/csv-upload.md) |
| `SUPPRESSED_BY` | the server's user name | `records:suppress` | Who is removing the record (free text, kept with the reason) |
| `PDF_TEXT` | `on` | `Collections::DigitalMedia.pdf_text?` | `off` reads no PDF text at indexing. See [pdf-full-text.md](../ead-ccs-test/docs/pdf-full-text.md) |
| `PDF_MEDIA_DIR` | `public/digital-assets/media` | `Collections::DigitalMedia.pdf_dir` | Where the PDF files are on the machine that indexes |
| `PDF_TEXT_MAX_MB` | `50` | `Collections::PdfText` | A larger PDF is skipped |
| `PDF_TEXT_TIMEOUT` | `30` | `Collections::PdfText` | Seconds a PDF may take to read |
| `FILM_ALL_COLLECTIONS` | unset | `ExploreEntryPoints`, `CatalogConfig::Facets`, `config/initializers/film_all_collections.rb` | Showcase film mode: lists every collection as a tile and in the Collection facet. For the private showcase copy only |
| `HARVESTED_CSV` | `data/harvested.csv` | `rake collections:index_harvested` | The CSV of harvested records that task indexes |
| `PDF_TEXT_MAX_CHARS` | `1000000` | `Collections::PdfText` | Text kept per PDF |
| `SEO_SITEMAP_CACHE_HOURS` | `12` | `BotControls.sitemap_cache_hours` | How long the list of record ids for the sitemap is kept |
| `TRENDING_ENABLED` | `on` | `RecordView.enabled?` | `off` stops counting record views and hides the Trending section (Featured and Pick of the day stay). See [similar-and-trending.md](../ead-ccs-test/docs/similar-and-trending.md) |
| `TRENDING_DAYS` | `7` | `RecordView.window_days` | The window of "most viewed in the last N days" (1 to 90) |
| `TRENDING_MIN_VIEWS` | `3` | `RecordView.min_views` | Views a record needs in the window to be trending; too few trending records and the section is left out |
| `TRENDING_KEEP_DAYS` | `35` | `RecordView.keep_days` | Days of view counts `bin/rails record_views:prune` keeps |
| `BOT_BLOCKED_USER_AGENTS` | empty | `BotControls.blocked_user_agents` | Comma-separated extra user-agent fragments to refuse (403) on asset and download files |
| `RATE_LIMIT_ALLOW_IPS` | empty | `BotGuard` | Comma-separated IP addresses never limited (a monitor, the office) |
| `RATE_LIMIT_STORE` | `memory` | `BotGuard` | `cache` counts in `Rails.cache`, shared between processes |
| `RATE_LIMIT_SEARCH_PER_MINUTE` | `120` | `BotGuard` | Per IP address: results and facet requests |
| `RATE_LIMIT_RECORD_PER_MINUTE` | `240` | `BotGuard` | Per IP address: record pages |
| `RATE_LIMIT_DOWNLOAD_PER_MINUTE` | `20` | `BotGuard` | Per IP address: zip and CSV endpoints |
| `RATE_LIMIT_ASSET_PER_MINUTE` | `600` | `BotGuard` | Per IP address: files under `/digital-assets` |
| `EMU_CSV` | `data/emu.csv` | `lib/tasks/collections.rake` | The EMu export to index |
| `VERNON_CSV` | `data/vernon.csv` | same | The Vernon export to index |
| `FORCE` | unset | same | `FORCE=1 bin/rails collections:index` reindexes a core that already has records |
| `CSV` | none (required) | `lib/tasks/debias.rake` | `bin/rails debias:import CSV=terms.csv` checks the collections team's term spreadsheet and writes the de-bias term list |
| `OUT` | `config/debias_terms.yml` | same | Where `debias:import` writes the list, to try an import without replacing the real list |
| `SOURCE_DIR` | `../public/assets/images/collections` | `lib/tasks/digital_assets.rake` | Where `digital_assets:*` reads source images |
| `CI` | unset | `config/environments/test.rb` | When set, tests eager-load the app, as GitHub CI does. `bin/ci` sets it |
| `PARALLEL_WORKERS` | CPU count | Rails test runner | `1` runs tests in one process; always use it for system tests |
| `PERF_RUNS` | `5` | `bin/perf` | Page loads per measurement |
| `PERF_SQL` | unset | `bin/perf` | Also prints the SQL statements |
| `PERF_LATENCY` | `170` | `bin/perf` | Browser mode: network latency in milliseconds |
| `PERF_DOWN_KBPS` | `1125` | `bin/perf` | Browser mode: download speed in kilobytes a second |
| `SOLR_OPEN_TIMEOUT` | `2` | `config/blacklight.yml` | Seconds to wait to connect to Solr before giving up (see [availability-reliability-scalability.md](../ead-ccs-test/docs/availability-reliability-scalability.md)) |
| `SOLR_READ_TIMEOUT` | `15` | `config/blacklight.yml` | Seconds to wait for a Solr answer |
| `READYZ_SOLR` | strict | `Readiness` | `optional` keeps `/readyz` at 200 ("degraded") while Solr is down, so an instance stays in rotation |
| `READYZ_TIMEOUT_SECONDS` | `2` | `Readiness` | Time limit for each `/readyz` dependency check |
| `READYZ_CACHE_SECONDS` | `2` | `Readiness` | How long a `/readyz` result is reused, so probes cannot load the database or Solr |
| `PUMA_SHUTDOWN_SECONDS` | `25` | `config/puma.rb` | How long Puma lets requests finish after SIGTERM before it stops them |
| `PUMA_FIRST_DATA_TIMEOUT` | `30` | `config/puma.rb` | Seconds Puma waits for a slow client's first bytes |
| `PUMA_PERSISTENT_TIMEOUT` | `20` | `config/puma.rb` | Seconds an idle keep-alive connection stays open |
| `DB_CONNECT_TIMEOUT` | `3` | `config/database.yml` | Seconds to wait to connect to PostgreSQL |
| `DB_CHECKOUT_TIMEOUT` | `5` | `config/database.yml` | Seconds a request waits for a free database connection |
| `DB_STATEMENT_TIMEOUT` | unset | `config/database.yml` | Milliseconds after which PostgreSQL cancels a slow query (off when unset) |
| `RESULTS_MAX_START` | `10000` | `SearchBuilder` | Results paging beyond this offset is clamped (ranking is unchanged) |
| `LOADTEST_DEBUG` | unset | `bin/loadtest` | Prints each client error while load testing |

`RAILS_ENV` and `BUNDLE_GEMFILE` are Rails' and Bundler's own and are not listed. The Solr image also reads `SOLR_MODULES`
(`analysis-extras`, set in the Dockerfile).
