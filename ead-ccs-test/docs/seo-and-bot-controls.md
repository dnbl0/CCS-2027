# SEO and bot controls (CCS-128, CCS-127, BR-18.04)

Two stories pull in opposite directions: be found by search engines (and cited by AI answer engines), but do not be harvested
by AI training crawlers and bulk scrapers. This page says what is on, what each setting does, how to turn it off, and where the
app's controls stop.

## Which pages are indexed

| Page | Search engines | Why |
| --- | --- | --- |
| Home, Help, About, Advanced search | indexed | the public front doors |
| Results of the whole site, or of one collection, page 1 | indexed | useful landing pages |
| Any other results page (search words, other filters, advanced clauses, page 2 on) | `noindex, follow` | endless near-duplicates; the records they link to are still followed |
| Record page `/catalog/:id` | indexed | the point of the site |
| Record page for a record whose asset is withheld (`:request` tier) or that is sensitive | `noindex, follow`, no structured data, no image, a general description | Indigenous cultural material is handled conservatively: its title and description stay out of search results |
| `/stock/:id`, `/branded-stock/:id` | `noindex, nofollow`, canonical to `/catalog/:id` | comparison copies of the record page |
| Search history, saved searches and records, lists, access requests, downloads, metadata export, sensitivity choice, citations, facet and range endpoints, error pages | `noindex, nofollow` | personal or action pages |
| Files under `/digital-assets` | `noindex` | people find records, not bare files |

The rules are in `RobotsPolicy`. The result goes out as the `X-Robots-Tag` header on every response (set in one place,
`BotGuard`) and again as `<meta name="robots">` (`layouts/_seo_head`), so they agree. Every public page also says
`noai, noimageai` (honoured by some AI crawlers; Google ignores it). With indexing off, every page is `noindex, nofollow`.

## What is generated

| Address | What | Code |
| --- | --- | --- |
| `/robots.txt` | AI crawlers disallowed by name; everyone else kept out of personal pages, endpoints and asset files; the Sitemap line. Googlebot and Bingbot follow the `*` group | `RobotsTxt` |
| `/sitemap.xml`, `/sitemaps/N.xml` | a sitemap index; each child holds at most 10,000 URLs (home, Help, About, Advanced search, default results, then every record page). Records come from Solr, read-only, by cursor, and are cached. Withheld and sensitive records, and every asset address, are left out | `Sitemap` |
| `/llms.txt` | a plain description of the site and a rights statement for AI systems. **Off by default; the rights wording is a placeholder that needs approval** | `SeoController` |
| every public page's head | meta description, canonical link, Open Graph and Twitter card tags, JSON-LD (the home page: `WebSite` with a `SearchAction` to `/catalog?q=...`; a record page: `CreativeWork`, or `VisualArtwork` for paintings, prints, photographs and the like) | `PageMeta`, `StructuredData` |

Page titles are the pages' own. A record's image appears in Open Graph, Twitter and JSON-LD only when the record is in the
`:open` tier, is not sensitive, and has a thumbnail (the 800 px thumbnail, never the large file).
Canonical links for results pages keep the search words, filters, range and advanced clauses (and the page after the first) and drop
`sort`, `view`, `per_page`, tracking parameters and anything unknown (`CanonicalUrl`).

## AI bot controls

1. **robots.txt** disallows the crawlers in `config/ai_crawlers.yml` (`training_and_scraping`). That file is the one place
   the lists live, with a comment on how to update it. AI *search and answer* agents (`ai_retrieval`: OAI-SearchBot,
   ChatGPT-User, Claude-User ...) are allowed, since being cited by them is the GEO half of the story; set
   `BOT_BLOCK_AI_RETRIEVAL=on` to disallow them too.
2. **403** for the listed crawlers, the scraper toolkits (`scrapers`) and `BOT_BLOCKED_USER_AGENTS`, on the asset files under
   `/digital-assets`, the zip download (`/downloads`) and the metadata CSV (`/catalog/:id/metadata`). The pages themselves stay readable.
3. **Rate limit** per IP address, a fixed one-minute window, answered with `429` and `Retry-After`.
4. `noai, noimageai` on every page (above).

No honeypot link was added. A trap link has to be invisible to assistive technology and keyboard users (`aria-hidden`,
`tabindex="-1"`, off-screen), and then a well-meaning crawler or a browser extension that follows every link would trip it; the
risk to real visitors outweighs the gain at this stage.

## Settings

All are environment variables. "on" is the only value that switches a setting on.

| Variable | Default | Effect |
| --- | --- | --- |
| `SEO_INDEXING` | `on` in production, `off` elsewhere | `off`: robots.txt is `Disallow: /`, every page is `noindex, nofollow`, the sitemap is a 404. **Set `off` on any test or staging copy that runs with `RAILS_ENV=production`** |
| `SEO_CANONICAL_BASE_URL` | the request's own address | fixes the site address in canonical links, the sitemap and structured data (for example `https://collections.unimelb.edu.au`) |
| `SEO_SITEMAP_CACHE_HOURS` | `12` | how long the list of record ids is cached |
| `SEO_LLMS_TXT` | `off` | `on` serves `/llms.txt` |
| `BOT_CONTROLS` | `on` | `off`: no AI-crawler rules in robots.txt, no 403s, no `noai` tags |
| `BOT_BLOCK_AI_RETRIEVAL` | `off` | `on`: AI search and answer agents are disallowed and blocked as well |
| `BOT_BLOCKED_USER_AGENTS` | empty | comma-separated extra user-agent substrings to 403 |
| `RATE_LIMIT` | `on` (`off` in the test environment) | `off` stops the rate limit |
| `RATE_LIMIT_SEARCH_PER_MINUTE` | `120` | `/catalog` results, facet and range requests per IP |
| `RATE_LIMIT_RECORD_PER_MINUTE` | `240` | record pages (`/catalog/:id`, `/stock/:id`, `/branded-stock/:id`) per IP |
| `RATE_LIMIT_DOWNLOAD_PER_MINUTE` | `20` | zip downloads and metadata CSV per IP |
| `RATE_LIMIT_ASSET_PER_MINUTE` | `600` | files under `/digital-assets` per IP (a results page of 96 images loads 96) |
| `RATE_LIMIT_ALLOW_IPS` | empty | comma-separated addresses never limited (monitoring, a partner) |
| `RATE_LIMIT_STORE` | `memory` | `cache` counts in `Rails.cache` |

The limits are well above what a person does (a handful of requests a minute), but a whole office or campus behind one address
shares one count: raise the limits, or list the address in `RATE_LIMIT_ALLOW_IPS`, if that happens.

## The rate limit and several processes

The counts live in the process by default (`memory`). With several processes or instances (Puma workers, several Azure
instances) each keeps its own count, so the real limit is the setting times the number of processes. That is acceptable for a
guard against runaway scrapers. For one shared count use `RATE_LIMIT_STORE=cache` with a shared cache store (for example Redis
or Memcached, set in `config/environments/production.rb`); the default production cache here is per-machine. The client address
comes from Rack, which trusts `X-Forwarded-For` only from private-network proxies; behind a proxy on a public address,
configure trusted proxies in Rails or the limit counts the proxy as one visitor.

## Limits: what the app cannot do

- **robots.txt is advisory.** Well-behaved crawlers follow it; others do not. `noai` tags are likewise only honoured by some.
- **User agents are spoofable.** The 403 stops crawlers that say who they are, and the scraper toolkits that do not hide it.
- **Real enforcement of heavy scraping is the CDN or WAF's job** (bot scoring, IP reputation, challenge pages, volumetric limits
  across instances). The app's limit is a backstop.
- **The files under `public/digital-assets` are still directly reachable** by anyone who knows or guesses the address, including
  the large files of records whose asset is withheld. The 403, the rate limit and `noindex` apply to them, but a withheld asset
  is not protected by them. Serving assets through a controller that checks `AccessPolicy` (or private storage behind the CDN) is
  the real fix, and is outside this work.
- **A searchable index can be harvested one record at a time.** The per-IP limits slow it; they do not stop a patient scraper
  using many addresses.

## Turning it off

`SEO_INDEXING=off` withdraws the site from search engines. `BOT_CONTROLS=off` and `RATE_LIMIT=off` turn the bot controls and the
limit off. To remove the middleware altogether, delete `config/initializers/bot_guard.rb`.

## Tests

`test/models/bot_controls_test.rb`, `robots_policy_test.rb`, `canonical_url_test.rb`, `structured_data_test.rb`,
`sitemap_test.rb`; `test/integration/seo_head_test.rb` (head tags and headers for each page type, with no asset address for a
`:request` or sensitive record), `seo_files_test.rb`, `personal_pages_robots_test.rb`, `bot_guard_test.rb`.
