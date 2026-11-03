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
| `PORT` | `3000` | `config/puma.rb` | The port Puma listens on |
| `PIDFILE` | unset | `config/puma.rb` | Puma pid file |
| `SOLID_QUEUE_IN_PUMA` | unset | `config/puma.rb` | Runs Solid Queue inside Puma; unused, the app has no jobs |
| `REDIS_URL` | `redis://localhost:6379/1` | `config/cable.yml` | Action Cable; unused, the app has no cable channel |
| `CCS_MEDIA_BASE_URL` | `/digital-assets/media` | `Collections::DigitalMedia` | Where the audio, video and PDF files are served from |
| `SEO_CANONICAL_BASE_URL` | the request's own address | `BotControls.base_url` | The site's address in canonical links, the sitemap and structured data, when a proxy hides the real host |
| `SEO_SITEMAP_CACHE_HOURS` | `12` | `BotControls.sitemap_cache_hours` | How long the list of record ids for the sitemap is kept |
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
