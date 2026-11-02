# Handover: Rails/Blacklight app (`ead-ccs-test`)

Written 2026-10-06 so a fresh session can continue. Current branch with the work:
`feat/blacklight-oob` (local, not pushed), on top of `feat/rails-ccs-theme`. Both were committed with
git plumbing off `origin/main`, because the parent repo's checked-out branch belongs to other work.
`data/*.csv` (20 MB of collection exports) is deliberately not committed.

## Status at 2026-10-07 (read this first; the sections below are from 2026-10-06)

- Work is on `dnbl0/CCS-2027` (formerly `dnbl0/CCS-Static-latest`), where this app lives in `ead-ccs-test/` beside the 2026 static
  prototype. The branches named below (`feat/blacklight-oob`, `feat/rails-ccs-theme`) are history.
- The app has the home, collections (browse list), help (one page with the FAQ, Indigenous data, Copyright and Contact Us sections) and
  about pages (`PagesController`, see the README), matching the static site; the search results are at `/catalog`. The collection
  landing pages, Contact and Search tips pages were removed (2026-10-16); their addresses redirect.
- Tests: `bin/rails test` (183 runs, no Solr needed) and `bin/rails test:system` (journeys and axe accessibility checks;
  they need Solr, see `docs/solr-dev.md`). Rubocop, Brakeman and the gem and importmap audits run in
  `.github/workflows/rails-ci.yml` at the repository root; the workflows under `ead-ccs-test/.github/` are the ones the
  app's own repository uses to deploy.
- The styles and images for the content pages are generated from the static site (`npm run sync:rails` at the repository
  root); do not edit them here. Plan and progress: `docs/code-quality-plan.md` at the repository root.
- Ruby: `.ruby-version` says 4.0.6 (CI uses it); the app also runs on 3.3.6.
- Solr: 10.0.0 from downloads.apache.org works (`bin/solr start -p 8984 --force`, then `bin/solr create -c blacklight-core
  -d solr -s http://127.0.0.1:8984`, with `SOLR_MODULES=analysis-extras`), then `bin/rails collections:index`.

## State

- Rails 8.1.3, Blacklight **9.0.0** (not 9.2.1), Ruby 4.0.6, Postgres 17, 99 tests passing (no Solr needed).
- Plugins: `blacklight-gallery` (git `main`, mosaic only; grid and slideshow removed; the rubygems 6.0.0 pins `blacklight ~> 9.0.0beta1`) and
  `blacklight_range_limit` 9.3.0. Config-only use; see `docs/blacklight-features.md`.
- Styling: tokens, themed Bootstrap (dartsass-rails), site header, footer, search overlay, breadcrumb
  and search banner as `NexusCcs::*` ViewComponents; see `docs/styling.md`.
- Run: `SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core bundle exec rails server -p 3002`
  (3000 is the static site). This app has its **own** Solr core (see `docs/solr-dev.md`); 40,962 records
  indexed with `rails collections:index`.
- Decision pending with D: the shared Solr on :8983 (used by `uom-collections`) was killed by mistake and
  a leftover process of mine holds the port. Do **not** touch :8983 or restart it without D's instruction.

## Evidence about Europeana and the British Museum

Observed live in Chrome by the side-panel agent on 2026-10-06; headless browsers are blocked by
Cloudflare on both sites, so treat these as the only rendered evidence.

- **Europeana current portal** is Nuxt 2.18 / Vue 2.7 / bootstrap-vue (`europeana/portal.js`), no Blacklight.
  Views: `?view=grid|list|mosaic`, default grid, persisted in a `searchResultsView` cookie. Filters are
  repeated `qf` params (`qf=collection:art&qf=TYPE:"TEXT"`) shown as removable chips beside the result
  count, with a "Clear filters" link and a "Search filters (n)" count in the sidebar. The sidebar always
  shows Theme, Type of media and "Can I use this?"; "Item quality" appears only once a Theme is chosen
  (a contextual facet); other facets sit behind "Show additional filters"; "Show advanced search" opens a
  query builder. Grid and mosaic interleave editorial cards; list rows had none. Results are capped at
  1,000 (26,547 matches showed 42 pages at 24 per page). List cards: provider above title,
  creator/description, rights + media type + Save/Like actions, thumbnail on the right.
- **Europeana code** (verified from clones): `packages/portal/src/components/search/SearchInterface.vue`,
  `SearchFilters.vue`, `SearchViewToggles.vue`, `components/item/ItemPreviewCardGroup.vue`,
  `ItemPreviewCardMosaic.vue`, `ItemPreviewCard.vue`, `utils/europeana/themes.js`,
  `plugins/europeana/search.js`. Full notes: scratchpad `europeana/source-specs.md`.
- **Europeana old portal** (`europeana-portal-collections`, archived 2022): Rails 4.2 + a forked
  Blacklight 6.0.2 + `europeana-blacklight` gem (custom Repository/SearchBuilder over the Search API).
  Its `app/controllers/concerns/blacklight_config.rb` has custom facet options worth reading if we ever go
  past out-of-the-box: hierarchical/parent, boolean toggles, range, `when:` lambdas per collection, `only:`
  filters, group/splice.
- **British Museum**: Drupal 11 (theme `numiko`), not Blacklight; GitHub org is unrelated R/DH scripts.
  URL scheme `/collection/search?keyword=&view=grid|list&sort=object_name__asc&page=N` (page 0-based,
  about 100 per page); term pages at `/collection/term/{id}`. Facet parameter names unverified.

## Data model

The facets, filter sections and record fields now come from the two workbooks in `data/` via `DataModel`
(see `docs/data-model.md`): 19 of 30 fields and 13 of 22 filters have source data; the rest are documented
gaps. The earlier pivot, query and contextual facets were removed because the workbook does not define them.

## Fixed since

- The Vernon CSV is double-encoded UTF-8 (for example "Inrō" read as "InrÅ"). `Collections::Text.repair_mojibake`
  now reverses it per character, including the control characters that Windows-1252 leaves undefined, and
  keeps its round-trip check so correct accents are untouched (3,415 suspect sequences to 0).

## Open issues and next steps (in suggested order)

1. **Decide the :8983 Solr** (D's call; see State).
2. **Images.** 30 records now show real assets (see `docs/blacklight-features.md`), taken from the static
   prototype's files; every other record shows a placeholder in the mosaic and nothing in the list. For
   all records, ask the EMu and Vernon owners for a derivative or IIIF URL, whether it is public, and
   rights/Indigenous cultural-data restrictions (`access_condition_ssi` and `restrictions_tsi` are
   deliberately not shown), then index it into `thumbnail_path_ssi` (or a URL field) instead of the YAML.
   The record page shows a record's images (`NexusCcs::DigitalAssetsComponent`).
3. **Dates.** About 12,700 of 41,000 records have no `date_start_isi` and about 1,700 are 0 or below, which
   distorts the range histogram. Either exclude year <= 0 from the range facet or fix it at index time.
4. **Style the rest** (the results layout, filter rail, drawer and record page are done and follow
   Europeana and the static design, see `docs/styling.md`): see `docs/styling-inventory.md` and the plan in `scratchpad/europeana/` (cards as one
   component with variants, left sticky 296px rail, drawer under 992px, accessible chips and drawer).
5. **Bookmarks** need a user model; `/bookmarks` redirects without one. The Blacklight guest-user /
   devise-guests pattern would make them work if D wants it.
6. **Lint.** Done: Rubocop is clean and runs in CI.
7. **Push and PR** `feat/blacklight-oob` (decide first whether `data/*.csv` belongs in this repo).

## Deferred custom work (D said leave out for now)

Editorial cards in results; custom facet UI (the facets are stock Blacklight by decision, 2026-10-13); British Museum style authority term pages; a view-preference cookie
beyond the session (Blacklight already stores the view in the session); a non-Solr API repository (avoid).

## Gotchas

- Never kill processes by command-line pattern (that killed the shared Solr). Take a PID from `lsof`.
- `form_with` drops `role:`; use `html: { role: "search" }`.
- Blacklight 9.0.0 `BookmarksController#verify_user` calls `action` (breaks on Rails 8.1); the app overrides it.
- The facet `if:` lambda receives the controller as its first argument; use `context.params`, not `search_state` (private).
- Blacklight remembers the last view in the session, so `?view=` matters when scripting checks.
