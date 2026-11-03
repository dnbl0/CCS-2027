# Availability, reliability and scalability (CCS-146, CCS-147, CCS-144)

The three stories give no numbers, and hosting is undecided. This page covers what the app does by itself, what it lets
the hosting do, and what only the hosting decision can supply. Nothing here assumes a cloud, a container platform or a CDN.

## In plain words

**What "available" means here.** A visitor can open the home, Help and About pages, and their own saved records, lists and
saved searches, even when Solr (the search index) is down. Searching and record pages need Solr. When Solr is down the
visitor sees a clear "Search is unavailable" page with a `Retry-After` header; the site does not hang and does not show a
stack trace.

| If this fails | What visitors get | What the app does |
|---|---|---|
| **Solr** (down, slow) | Home, Help, About, saved records, lists (their records named by id), saved searches and history still open. Searches and record pages say "Search is unavailable" (503, `Retry-After: 30`). The header's collection counts show the last good numbers. | Timeouts of 2 s (connect) and 15 s (read). One retry of a refused connection. After 5 failures in a row, Solr is not asked for 10 s, so a dead Solr costs one quick refusal rather than a timeout per request. It tries again by itself. |
| **The database** | Home, Help and About still open (the header's saved-records count shows 0). Anything that needs the database shows the friendly "The service is busy or unavailable" page (503, `Retry-After: 30`). | Short connect and pool-wait timeouts, so threads are not held. The error is logged as a JSON line. |
| **One instance** | Nothing, if there is more than one instance behind a load balancer that uses `/readyz`. | `/healthz` and `/readyz` say whether to restart or to stop sending traffic. Shutdown drains requests. |

**What scales and what does not.** The app is stateless: the session is in a cookie, nothing is written to disk except
`tmp/`, and there are no uploads. You can run several instances behind a load balancer. Four things are kept per process
and so are only approximate across instances: the rate limit's counts, the cache (collection counts, sitemap record list),
and the access-request rate limit. Each can be made shared by setting `CACHE_STORE=solid_cache` and
`RATE_LIMIT_STORE=cache`. What does not scale in the app is Solr and PostgreSQL themselves: each is one server today.

## Probes: `/up`, `/healthz`, `/readyz`

| Path | Question | Checks | Answer |
|---|---|---|---|
| `/up` | Did the app boot? (Rails' own) | nothing | 200, or 500 |
| `/healthz` | Is the process alive and answering? **Liveness.** | nothing else, so it stays 200 while the database or Solr is down | `{"status":"ok"}` |
| `/readyz` | Should this instance get visitors? **Readiness.** | database (`SELECT 1`), Solr (its ping handler, short timeout), migrations current | 200 `{"status":"ok","checks":{"database":"ok","solr":"ok","migrations":"ok"}}`, or 503 with the failing check marked `"fail"` |

All three: JSON, `Cache-Control: no-store`, `X-Robots-Tag: noindex, nofollow`, no cookie, not counted by the rate limit, not in
`robots.txt` crawl paths, excluded from the HTTPS redirect and the host check, and kept out of the request log. They reveal
only "ok" or "fail" for each check: no host, port, version, database name or error text (tested in
`test/integration/health_test.rb`).

How to use them (any orchestrator or load balancer):

- **Liveness probe** → `/healthz`. Restart the instance only when this fails. Never point liveness at `/readyz`: a Solr outage
  would then restart every instance and make things worse.
- **Readiness probe / load balancer health check** → `/readyz`. Take the instance out of rotation when it returns 503.
  Suggested: every 5 to 10 s, timeout 3 s, remove after 3 failures, return after 2 successes.
- **Startup probe** → `/healthz` (or `/up`), allowing 60 s for boot.
- Set `READYZ_SOLR=optional` if the instance should stay in rotation while Solr is down, serving the pages that do not
  search. `/readyz` then returns 200 with `"status":"degraded"`. The default is strict: every instance would be removed
  during a Solr outage, and the load balancer's own error page would replace the site's friendlier one. Decide this with the
  hosting (question 5 below).
- Solr's answer is remembered for 2 s, so many probes cost one ping.

## Details

### Availability (CCS-146)

- **Boot with Solr down.** Nothing contacts Solr at boot. The app starts, `/healthz` is 200, `/readyz` is 503, and the
  static pages are served (checked by starting production mode with Solr unreachable).
- **Boot with the database down.** The app starts too; pages that need it answer 503 and `/readyz` fails. Migrations are not
  run by the app on boot except by the Dockerfile's `db:prepare` (see "Not done").
- **Graceful shutdown.** `config/puma.rb`: on SIGTERM Puma stops accepting connections and lets requests in flight finish, for
  up to `PUMA_SHUTDOWN_SECONDS` (25). The Dockerfile now `exec`s the server so Puma, not a shell, receives the signal. Keep the
  platform's termination grace period above `PUMA_SHUTDOWN_SECONDS`. Slow or silent clients are cut off by
  `PUMA_FIRST_DATA_TIMEOUT` and `PUMA_PERSISTENT_TIMEOUT`.
- **Drain order for a rolling deploy:** new instance becomes ready → old instance leaves the load balancer (readiness) →
  SIGTERM → drain → exit.

### Reliability (CCS-147)

- **Solr client** (`lib/solr_guard.rb`, prepended to Blacklight's repository). All the site's Solr requests are reads, so all
  are safe to repeat. Only a *refused connection* (nothing was sent) is retried, once, after a short randomised pause. A
  timeout is never retried: that would double the wait on a server that is already slow. A Solr 400 (a bad query) is not an
  outage and does not count.
- **Circuit breaker** (`lib/circuit_breaker.rb`, plain Ruby, one per process). Closed → after `SOLR_BREAKER_THRESHOLD` failures in
  a row it opens → for `SOLR_BREAKER_RESET_SECONDS` every call is refused at once → then one probe is let through (half open);
  success closes it, failure opens it again. So with Solr down, a Puma thread is held for milliseconds, not 15 s.
- **Degraded pages.** Search, record and facet pages answer the existing "Search is unavailable" page (HTTP 503,
  `Retry-After`). `BrowseMenu` keeps the last good counts for 30 days and falls back to them. A list opens with its record ids
  as links when Solr is down.
- **Database errors** (`ActiveRecord::ConnectionNotEstablished`, pool timeout, and so on) map to 503, shown as the site's
  "The service is busy or unavailable" page, with `Retry-After`. If the error page itself cannot be drawn, the static
  `public/503.html` is sent.
- **Error pages.** 400, 404, 406, 422, 429, 500 and 503 are all in the site's header and footer (`ErrorsController`), with plain
  wording, a way on, a contact link, `noindex`, and `Retry-After` for 429 and 503. Static fallbacks exist in `public/`. axe checks
  each in `test/system/error_pages_accessibility_test.rb`.
- **Error reporting.** `Rails.error.report` and unhandled exceptions reach `ErrorLogSubscriber` (`lib/error_log_subscriber.rb`),
  which writes one JSON line: time, level, handled, error class, message (cut to 500 characters), request id, method, path (no
  query string, no parameters, no cookies), and the top five application frames. The request id is also the log tag for every
  line. To add an external service (Sentry, Honeybadger, Application Insights, Datadog): add its gem, then in
  `config/initializers/resilience.rb` add `Rails.error.subscribe(TheirSubscriber.new)`. Every call site is already reporting
  through `Rails.error`, so nothing else changes. (No gem was added here.)
- **Malformed input.** Broken `%`-encoding, bad JSON, oversize bodies and queries, and parameters of the wrong type are answered
  with 400, 413 or 414, never 500 (`test/integration/hostile_urls_test.rb`). The error page for a failed POST no longer re-reads
  the broken body.
- **Safe writes.**
  - Save a record: a lock on the visitor's row makes two requests take turns, so there is one bookmark.
  - Create list: a repeat within 10 s finds the first list; the unique index (name, ignoring case) settles two at once.
  - Add to list: the unique index is caught and reported as "already in the list".
  - Save a search: `SavedSearch.keep` finds the same name and parameters under a lock.
  - Access request: `AccessRequest.submit` takes a database advisory lock on document, email and kind, and returns the
    earlier identical request (10 min window). A repeat is answered with the same confirmation.
  - Tests: `test/integration/double_submit_test.rb`.

### Scalability (CCS-144)

**Per-process state.** Run several instances and each of these is separate:

| Thing | Where | What breaks when scaled out | Fix |
|---|---|---|---|
| Rate-limit counts (BotGuard) | `BotGuard::MemoryStore` | Real limit = limit × instances (× workers) | `RATE_LIMIT_STORE=cache` with a shared `CACHE_STORE`, or the CDN/WAF |
| Access-request rate limit | `AccessRequestsController::RATE_STORE` | Same | `RATE_LIMIT_STORE=cache` also moves this |
| `Rails.cache`: collection counts, sitemap record list | `CACHE_STORE` | Each instance fetches its own (one Solr request each, then cached); the sitemap list is a full Solr cursor per instance per `SEO_SITEMAP_CACHE_HOURS` | `CACHE_STORE=solid_cache` (database) or `file` on a shared volume |
| Circuit breaker | per process | Each instance learns Solr is down for itself (one failed request each) | none needed |
| Readiness cache (2 s) | per process | none | none |
| Session | cookie | nothing: no server-side session | none |
| Files | none written except `tmp/` and the bulk-download zip (a temp file, removed after the response) | nothing | none |

**Cache store.** `CACHE_STORE` = `memory` (default, `CACHE_MEMORY_MB` 64), `file` (`CACHE_PATH`), `solid_cache` (shared through the
database; a migration adds `solid_cache_entries`) or `null`. The cache holds only rebuildable data, so losing it costs speed.
Redis or Memcached would need a gem: add it and a branch in `lib/cache_store_config.rb`.

**Connections.** Per instance, database connections = `WEB_CONCURRENCY` (Puma workers, default 0 = single process) ×
`RAILS_MAX_THREADS` (default 3 in Puma, pool of the same size in `database.yml`, which falls back to 5 if the variable is unset:
set it). Total = instances × workers × threads, plus a few for migrations and the readiness check. It must stay below
PostgreSQL's `max_connections` (default 100) with headroom: for example 4 instances × 2 workers × 5 threads = 40. A
pooler (PgBouncer, or the managed service's) lifts this limit. Solr has no such pool in the app; each thread makes its own HTTP
request, so 40 threads can send 40 concurrent requests to one Solr.

**Unbounded or growing paths, and their limits.**

| Path | Limit |
|---|---|
| List | 25 lists per visitor, 200 records per list; the list page makes one Solr request for up to 200 ids and one SQL query for its items |
| Saved searches | 100 per visitor (new), page lists at most 100 |
| Saved records | 500 per visitor (new); the page fetches them in one Solr request |
| Results | page size is capped at 100 by Blacklight (`max_per_page`; the menu offers 12, 24, 40 and 96); a page starting beyond record 10,000 (`RESULTS_MAX_START`) is answered with the last page inside it. Ranking is unchanged. |
| Request body / query string | 1 MB (`REQUEST_MAX_BYTES`) / 8 KB (`QUERY_STRING_MAX_BYTES`) → 413 / 414 before parsing. Rack caps parameters at 4096 and nesting at 100. |
| Bulk download | 25 records, 100 files, 200 MB, and the rate limit's "download" kind (20 a minute) |
| Metadata CSV | one record, rate limited as "download" |
| Access-request export | `find_each` in batches of 1,000, so memory stays flat as requests grow |
| Search history | Blacklight's own, trimmed by `SearchHistoryDays` |

N+1 queries on these pages were checked with the existing performance budgets (`test/integration/performance_test.rb`); the lists page
loads items once with `includes`.

## Settings

All are optional; defaults are safe.

| Variable | Default | Meaning |
|---|---|---|
| `SOLR_OPEN_TIMEOUT` / `SOLR_READ_TIMEOUT` | 2 / 15 | Seconds to connect to Solr / wait for an answer |
| `SOLR_RETRIES` | 1 | Retries of a refused connection |
| `SOLR_BREAKER_THRESHOLD` | 5 | Failures in a row that open the circuit |
| `SOLR_BREAKER_RESET_SECONDS` | 10 | How long it stays open before a probe |
| `READYZ_SOLR` | (required) | `optional`: a Solr outage gives 200 "degraded" |
| `READYZ_TIMEOUT_SECONDS` / `READYZ_CACHE_SECONDS` | 2 / 2 | Bound per check / how long Solr's answer is remembered |
| `PUMA_SHUTDOWN_SECONDS` | 25 | Drain time on SIGTERM |
| `PUMA_FIRST_DATA_TIMEOUT` / `PUMA_PERSISTENT_TIMEOUT` | 30 / 20 | Slow-client cut-offs |
| `WEB_CONCURRENCY` / `RAILS_MAX_THREADS` | 0 / 3 | Puma workers / threads (and the pool size) |
| `DB_CONNECT_TIMEOUT` / `DB_CHECKOUT_TIMEOUT` | 3 / 5 | Seconds to reach the database / get a pooled connection |
| `DB_STATEMENT_TIMEOUT` | (none) | Milliseconds before a query is ended |
| `CACHE_STORE`, `CACHE_PATH`, `CACHE_MEMORY_MB` | memory, tmp/cache, 64 | See Cache store |
| `RATE_LIMIT_STORE` | memory | `cache`: counts in `Rails.cache` |
| `RESULTS_MAX_START` | 10000 | Deepest result offset |
| `REQUEST_MAX_BYTES` / `QUERY_STRING_MAX_BYTES` | 1048576 / 8192 | Request size limits |

(The existing `RATE_LIMIT*` and `SEO_*` settings are in `docs/seo-and-bot-controls.md`.)

## Load test and baseline

`bin/loadtest` (plain Ruby, no gems) ramps concurrent clients against a running instance and prints p50/p90/p95/p99/max latency,
requests per second and the error rate, per scenario (`home`, `results`, `record`, `health`, `ready`). It exits 1 above
`--max-errors-percent` (default 1). Start the instance with `RATE_LIMIT=off`, or the rate limit will answer 429. Run it from
`ead-ccs-test/`: `bin/loadtest --levels 1,2,4,8 --seconds 8`. Be gentle: `results` and `record` hit Solr.

**Baseline** (3 Nov 2026, developer laptop, Apple silicon, production mode, one Puma process with 5 threads, PostgreSQL and the shared
40,962-record Solr on the same machine, load generator on the same machine, rate limit off, 6 s per level, results for "skull" with
assets, the record is the first result):

| Scenario | Clients | Requests/s | p50 ms | p95 ms | p99 ms | Errors |
|---|---|---|---|---|---|---|
| home | 1 | 197.8 | 4.8 | 5.9 | 8.0 | 0.00% |
| home | 2 | 217.0 | 9.0 | 10.8 | 14.4 | 0.00% |
| home | 4 | 225.5 | 17.6 | 22.8 | 26.2 | 0.00% |
| home | 8 | 199.8 | 35.4 | 64.9 | 160.0 | 0.00% |
| health | 1 | 2125.5 | 0.4 | 0.6 | 0.9 | 0.00% |
| health | 2 | 2504.8 | 0.8 | 1.1 | 1.5 | 0.00% |
| health | 4 | 2513.5 | 1.5 | 2.3 | 2.8 | 0.00% |
| health | 8 | 2539.8 | 3.1 | 4.7 | 5.5 | 0.00% |
| ready | 1 | 646.0 | 1.3 | 2.5 | 5.3 | 0.00% |
| ready | 2 | 1102.0 | 1.7 | 2.4 | 4.3 | 0.00% |
| ready | 4 | 1168.5 | 3.2 | 4.6 | 8.0 | 0.00% |
| ready | 8 | 1036.5 | 6.7 | 11.8 | 31.0 | 0.00% |
| record | 1 | 54.8 | 15.1 | 33.1 | 46.5 | 0.00% |
| record | 2 | 50.8 | 34.1 | 74.4 | 134.1 | 0.00% |
| record | 4 | 57.5 | 57.6 | 138.3 | 216.2 | 0.00% |
| record | 8 | 76.5 | 101.4 | 153.8 | 189.8 | 0.00% |
| results | 1 | 10.3 | 89.1 | 127.9 | 135.9 | 0.00% |
| results | 2 | 11.7 | 168.0 | 200.5 | 269.8 | 0.00% |
| results | 4 | 12.0 | 335.1 | 506.9 | 585.9 | 0.00% |
| results | 8 | 13.3 | 614.5 | 808.5 | 932.2 | 0.00% |

How to read it: one process on one machine is the limit here. Throughput stays flat as clients rise, and latency grows in
proportion (the queue in front of the Ruby threads), with no errors up to 8 clients. The probes are cheap: `/healthz` about
2,500 requests/s, `/readyz` about 1,100 (its Solr ping is remembered for 2 s). A results page is the costliest page, mostly
Solr and its rendering: about 10 to 13 requests/s per process. Real capacity comes from adding processes and instances, and from
a bigger Solr; this baseline is for comparing runs on the same machine, not for sizing production. The test also does not include
browsers, TLS, a network or a CDN.

## What could not be done at app level (needs the hosting decision)

These are recommendations, with the question each decision must answer.

1. **Uptime target and SLA.** Without a number there is nothing to design to. *Questions:* what availability does the University
   expect (for example 99.5% ≈ 3.6 h down a month, 99.9% ≈ 43 min)? Does it cover planned maintenance? Is Solr outage "down"
   or "degraded"? Who is on call, in what hours?
2. **Multi-instance and multi-zone failover.** The app is ready for it (stateless, probes). *Questions:* how many instances, in
   how many zones or sites? What does the load balancer do on failure, and does it use `/readyz`? What is the recovery time target
   for a lost zone?
3. **Autoscaling.** Needs a platform and a signal (CPU, requests, queue depth). *Questions:* expected peak (a teaching
   semester, a launch, a news mention)? How fast must it add capacity? Use the baseline above to size one instance.
4. **Managed PostgreSQL.** Replication, failover and a connection pooler. *Questions:* single server with backups, or a replica with
   automatic failover? What is the data-loss tolerance (RPO)? Visitor data is small (guest lists, saved searches, access
   requests), but access requests are staff-facing records.
5. **Solr availability.** One Solr is a single point of failure for search. *Questions:* is a replicated cluster (SolrCloud or
   a read replica) warranted, or is rebuilding the index from source quick enough? Should instances stay in rotation during a Solr
   outage (`READYZ_SOLR=optional`)? Who owns re-indexing?
6. **Backups and restore tests.** Nothing in the app can do this. *Questions:* backup schedule and retention for PostgreSQL;
   how Solr is rebuilt; who tests a restore, how often, and against what recovery-time target.
7. **Monitoring and alerting.** The app emits JSON error lines with request ids and has probes, but nothing watches them.
   *Questions:* which service collects logs, errors and metrics? Which alerts page someone (readiness failing for N minutes, 5xx
   rate, p95 latency, Solr or database saturation, certificate expiry)? Synthetic checks from outside the network?
8. **CDN / edge caching and WAF.** Would offload the asset files and give an exact, shared rate limit and DDoS protection. The app
   already sends cache headers and compresses text. *Questions:* is a CDN allowed, and may it cache HTML for anonymous visitors?
9. **Migrations on deploy.** The Dockerfile runs `db:prepare` at start, which races when several instances start together and
   is awkward for rollbacks. Recommended: a one-off job before the rollout. `/readyz` already fails an instance whose migrations
   are behind.
10. **A shared cache for exact limits.** `CACHE_STORE=solid_cache` works with no extra service but adds load to PostgreSQL; a
    dedicated Redis or Memcached needs a gem and a hosting decision.
11. **Disaster recovery and capacity tests** at production size, in the production network, rather than on a laptop.
