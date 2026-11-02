# Code quality plan

A plan to make both codebases clean, well structured and in line with best practice: the **static site** (`public/`,
`scripts/`, `tests/`) and the **Rails/Blacklight app** (`ead-ccs-test/`). Written 2026-10-07 after the Rails app gained
the home, collections, help and contact pages.

Each item has a size (S under half a day, M a day or two, L longer) and a check that shows it is done. The phases are
in priority order; phases 1 and 2 are the ones that stop things going wrong, the rest is tidying.

## Where things stand

| Area | Static site | Rails/Blacklight |
|---|---|---|
| Tests | 19 node suites in `npm test` (6 need Chromium, skipped in some environments) | 168 Minitest runs; one system test |
| Lint | none for CSS, JS or HTML | Rubocop (omakase) and Brakeman clean |
| CI | `ci.yml` runs `npm test` | `rails` job added to `ci.yml` (Rubocop, Brakeman, tests) |
| Largest files | `search-results.css` 75 KB, `record.css` 30 KB, `support.js` (generated runtime) 1,900 lines | `catalog_controller.rb`, `record_page.css`, `advanced_search.css` |
| Duplication | five collection landing pages of 769 lines each differ only in data; header and footer repeated in every page | `pages/static_shared.css` and `tokens/static_site.css` are copies of static files |

Mobile (390px) check, 2026-10-07: home, collections, a collection, contact, help and indigenous data pages have no
horizontal overflow on either site, the computed font sizes and spacing match, and the menu drawer matches. One
difference was found and fixed: the Rails mobile breadcrumb back link was dark on dark (the per-page `.bc-mobile*`
rules did not travel with the copied markup; they are now one shared rule set). Remaining visual differences are the
search bar on the home page (the Rails app keeps its Blacklight bar) and font fallback in offline test runs.

## Progress

- **Done 2026-10-07 (Phase 1):** decision taken (shared source for tokens, CSS and images; copy stays separate), items
  2 and 3 built (`scripts/sync-rails-assets.js`, `scripts/parity.js`, `parity.js` was later removed from CI and the repo), item 4 settled by documentation,
  and items 6 and part of 5 done (CI split into `ci.yml` and `rails-ci.yml` with path filters, the Rails job gained
  gem and importmap audits).
- Item 5 changed: `ead-ccs-test/.github/workflows/deploy.yaml` builds and deploys the Rails image through the
  organisation's `unimelb-enterprise-apps` actions and its secrets. Those only work in the repository that owns them,
  so the nested workflows and `dependabot.yml` are left in place. They run if `ead-ccs-test` is published as its own
  repository. Decision (2026-10-07): keep them. They are the organisation repository's own CI and deploy; deleting `deploy.yaml` could stop deployments, and they cost nothing here. `ead-ccs-test/.github/README.md` says so.
- **Done 2026-10-07 (Phase 3, items 10-12):**
  - Item 10: ESLint (`eslint.config.js`, 0 errors, 12 warnings to clean up) and Stylelint (`.stylelintrc.json`, 0
    errors, 23 warnings: duplicate selectors and `!important`) run first in `npm test` (`npm run lint`). HTML
    validation is left out: the pages are DC templates with `{{ }}` and custom tags that validators reject.
  - Item 11 (superseded 2026-10-16: the collection pages, their template and `build-collection-pages.js` were removed;
    a collection is now the filtered results, see `docs/adr/0002`): the five collection pages are generated from `src/collection-landing.template.html` by
    `scripts/build-collection-pages.js` (output unchanged, byte for byte); `--check` runs in `npm test`.
  - Item 12: the header, search overlay and footer are `src/partials/*`, written into every page by
    `scripts/sync-partials.js` (`--check` in `npm test`). Three pages changed: the contact page's Contact link class,
    the search page's search button class (neither is styled) and the home page footer's image paths (now absolute).
    The page-named BEM classes in the header (`contact-university-melbourne__list`) are kept: the partial is a template
    with `@PAGE@`.
- **Done 2026-10-07 (more):**
  - Item 13 (part): `search-results.css` is split into eight files under `public/styles/pages/search-results/`, cut
    only at the section comments that were already there and loaded in the same order, so the cascade is unchanged.
    It is not yet split by component: the sheet is layered (later rules refine earlier ones, 23 duplicate-selector
    warnings), so merging the layers needs the Chromium `style-diff` suite to prove nothing moved. Do that in CI.
  - Item 18: `HelpTopic`, `SitePages` and `CollectionCounts` replace the logic in `PagesController`; breadcrumb, page
    banner and pathfinder card are ViewComponents with tests.
  - Item 7: `auto-merge.yml` no longer fires for changes under `ead-ccs-test/`. Item 8: a pull request template asks for
    the checks and for desktop and mobile screenshots (no `CODEOWNERS` yet: it needs the owners' usernames).
- **Done 2026-10-07 (item 14, first step):** the page runtime no longer needs unpkg.com. `public/runtime-libs.js`
  (loaded before `support.js` on every page) maps the three CDN URLs to the exact builds in `public/vendor/runtime`,
  using the runtime's own `__resources` hook, so `support.js` (generated, not edited) is untouched.
  `tests/runtime-libs.test.js` checks the load order and that the files match the hashes `support.js` pins. The pages
  now render offline and the Chromium suites run in the sandbox: search-bar, results-filter-parity, image-aspect,
  style-diff and search-live pass, accessibility passes (30 page states; one run flagged a contrast failure while
  results were still rendering and did not repeat). `advanced-filters` failed 5 keyboard checks. I first put that down to the
  sandbox because it failed on the code from before this work too; that was wrong. It failed because serving React locally
  made the runtime render the form before `advanced-search-form.js` ran, and the runtime copies the DOM that script builds
  (markup and `data-ready`, not the listeners), so the dropdowns in the search rows did nothing. With the CDN's slower load the
  race went the other way. Fixed in the script (it now records the form element it enhanced, instead of trusting an attribute
  that survives the copy, and clears what was copied); all seven browser suites pass.
- **Pre-rendering, assessed:** with the CDN dependency gone the remaining cost is speed: Babel (3 MB) compiles every
  page's template at load. The interactive pages (search results, record, advanced search) need the runtime whatever
  is done, so pre-rendering would only cover contact, help, indigenous data, the browse page and the collection pages,
  and the help topics would need their own URLs (today `?topic=`). Worth doing if first paint on those pages matters;
  not needed for correctness.
- **Done 2026-10-07 (item 19):** `CatalogController` went from 263 to 165 lines. The facet, record field and search
  field configuration is `CatalogConfig::Facets`, `RecordFields` and `SearchFields` (`app/models/catalog_config`), and the
  range histogram action's Solr work is `RangeHistogramQuery`. The resulting Blacklight configuration is identical to
  before (checked by dumping it from both versions). The histogram endpoint had no tests; it now has endpoint and query tests.
- **Done 2026-10-07 (item 13):** the search results styles are nine files by component (`layout`, `results`, `toolbar`,
  `banner`, `flyout`, `filters`, `facet-rail`, `pagination`, `pills`), the largest 20 KB. The 14 duplicate selectors were
  merged one at a time and the regrouping was done in one step; both were checked with the repo's computed-style
  snapshot tool (`style:snapshot` / `style:diff`) on the search page: 14 states and widths, 0 differences. The
  snapshots cover those states only, so a hover or focus state outside them is not proven. `stylesheet-structure`
  now fails a stylesheet over 32 KB. Nine duplicate-selector warnings remain (record.css and some inside media queries).
- **Done 2026-10-07 (item 22, system tests):** the Rails app had a system test that could not run (its base class,
  `test/application_system_test_case.rb`, did not exist). It now has one (Cuprite, headless Chrome) and six journey
  tests: home search, mosaic/list, filtering, opening a record and back, the advanced search panel, the phone menu.
  Running them needs Solr; a `system` job in `rails-ci.yml` downloads Solr 10, creates the core, indexes the CSVs and
  runs them. I ran them here against a real Solr (Solr 10 from downloads.apache.org, 40,962 records) three times, all
  green. The CI job itself has not run on GitHub yet. Two things the work turned up: the old Acknowledgement of Country
  test expected the dialog at `/`, which stopped being true when `/` became the home page, so the home page now shows it
  (once a day per browser) and the test is updated; and `catalog/_home_text` is dead code since the front page moved.
- **Done 2026-10-07 (item 15):** gates on both sides.
  - Rails: `test/system/accessibility_test.rb` runs axe-core (WCAG 2.1 A and AA) on the home, browse, collection, help, help
    topic, indigenous data, contact, search results and record pages and on the home page with the Acknowledgement of
    Country open: all 10 clean, and a test proves the check fails when a page has a violation. They run in the `system` job.
  - Static: `tests/browser-available.test.js` fails in CI (`CI=true`) when there is no Chromium, so the accessibility and
    other browser suites cannot be silently skipped; `tests/budgets.test.js` caps the stylesheets (220 KB), scripts
    (650 KB) and any one image (800 KB) a page names (current largest: 187 KB of CSS, 590 KB of scripts, a 672 KB image).
    Lighthouse budgets are not added: they measure a build served over a network, which this site does not have yet.
- **Done 2026-10-07 (small):** `hello_controller.js` removed (item 21); `ead-ccs-test/docs/handover.md` has a current status
  section (item 24).
- **Done 2026-10-07 (the rest):**
  - Item 16: the README's changelog moved to `CHANGELOG.md`, and the README documents the generated files and commands.
  - Item 17: `erb_lint` (`.erb_lint.yml`, `bin/erb_lint`) is clean (35 whitespace fixes, autocomplete attributes on three
    inputs) and runs in the `rails` CI job. The Rails CSS is linted by `npm run lint:rails-css` (0 errors, warnings for
    `!important` and duplicate selectors); linting found a dangling comment at the end of `site_header.css`, now removed.
  - Item 20 (part): the `!important`s in the Rails CSS (24, mostly overrides of Bootstrap's `.visually-hidden` and
    margins) are reported as warnings, not removed: removing them needs a visual check of the results page for each, and a
    wrong one would be visible to everyone.
  - Item 23 (part): a Solr that is down or refuses a request now gives a "Search is unavailable" page (HTTP 503; JSON too)
    instead of a stack trace, the pages that do not search keep working, and Solr has connect and read timeouts
    (`config/blacklight.yml`). Tested.
  - Item 27: `npm audit --omit=dev` runs in the static CI job (0 vulnerabilities: the site has no runtime npm
    dependencies); `bundler-audit`, `importmap audit` and Brakeman already ran. The dev tooling has 6 high advisories
    in stylelint's dependency `braces`; they are not shipped, so they are reported, not blocking.
  - Items 25 and 28: `docs/conventions.md` holds the naming, the "where a change is made" table and an accessibility checklist.
- **Not done, on purpose:**
  - Enforcing the Content Security Policy (item 23): it is now on in report-only mode (`config/initializers/content_security_policy.rb`,
    tested), so browsers report violations without blocking. Look at the console on every page; when quiet, set
    `content_security_policy_report_only = false`.
  - Unit tests for the Stimulus controllers (item 21): the system tests exercise the controllers that matter (flyout,
    menu, dropdowns); a JS test runner would be a new dependency for little extra cover.
  - One list of collections (items 25, 26): in Rails it is now one place (`config/pages.yml`; the header menu is built from it,
    and a test checks it against the static site's collection folders). The static build script still has its own list, and the
    data model workbook is still copied into both sites.
  - Pre-rendering the static content pages (item 14): assessed above; only worth it if first paint on them matters.
  - Item 9: Brakeman must be bumped by hand when it releases (`bin/brakeman` fails on an outdated gem); Dependabot is set up.
  - Removing the `!important`s and the remaining duplicate-selector warnings (see above).
