# Maintainability (CCS-149, BR-18.04)

Measured on branch `nfr/maintainability-ccs-149`, November 2026. Re-run the measurements with the commands in the last section.

## In plain language

**The Rails app is easy to change safely, and hard to learn without a guide; the guide now exists.** The code is small (5,600 lines
of Ruby, 7,600 of CSS, 1,100 of JavaScript), split into small objects that each start with a comment saying what they decide, and
99% of its lines are run by the unit suite (664 test runs, 12 seconds; 152 browser tests, 2 minutes). Almost no method is long
or tangled. A new developer's real difficulties were elsewhere: no overview, no list of settings, no recipe for a common change,
a CI that could not be run locally, a branch-name trap that merges without CI, and old documents that contradict the app.
This work adds those, and pins the one untested area (the indexers and `SearchService`) with tests.

**Where it is still hard:**

1. The Solr schema, the ingest and the DAM metadata belong to the dev team and are not in this repository. The two stand-in rules
   (`AccessPolicy`, `Sensitivity`) will need replacing when the DAM classification arrives; each says which lines.
2. The 2026 static prototype (`public/`, `src/`, `scripts/`, root `package.json`) is still in the repository, and some page
   styles still say "Generated... edit the static file". See `docs/decoupling-from-2026.md`.
3. Several documents are historical and say so only at the top (`ead-ccs-test/docs/handover.md`, `secrets.md`, `docs/HANDOFF.md`).
4. Rate limiting is per process (ADR 0010), and `static_shared.css` is one 1,279-line file.

## Evidence

### Test coverage (`bin/coverage`, unit suite, Solr up; Ruby's built-in Coverage)

| Directory | Files | Lines | Covered | Before | After |
|---|---|---|---|---|---|
| app/components | 54 | 622 | 616 | 99.0% | 99.0% |
| app/controllers | 22 | 468 | 458 | 97.9% | 97.9% |
| app/helpers | 5 | 49 | 49 | 100% | 100% |
| app/indexers | 11 | 287 | 286 | 59.6% | **99.7%** |
| app/models | 40 | 870 | 870 | 100% | 100% |
| app/services | 1 | 24 | 24 | 62.5% | **100%** |
| lib | 4 | 137 | 134 | 97.8% | 97.8% |
| app/jobs, app/mailers (empty stubs) | 2 | 4 | 0 | 0% | 0% |
| **Total** | 139 | 2,461 | 2,437 | 94.0% | **99.0%** |

Without Solr (as in GitHub's `rails` job) the total is 92.6%: `SearchService` drops to 25% because its tests need the index.
Line coverage says a line ran, not that its behaviour is checked; the model tests do assert behaviour, the controller tests mostly
check the page renders.

### Largest and most complex code

Longest Ruby files: `catalog_controller.rb` 186, `citation.rb` 162, `bulk_download.rb` 146, `emu_source.rb` 134,
`digital_assets_component.rb` 133, `bot_guard.rb` 130. Largest CSS: `pages/static_shared.css` 1,279, `tokens/static_site.css` 644,
`components/record_page.css` 471. Largest view: `pages/help.html.erb` 168. Measured with RuboCop Metrics at thresholds stricter than the
project's (method 15 lines, ABC 20, cyclomatic 8, class 150), which are *not* enforced: 67 offences in 15 files, none a class
over 150 lines. Top 15 by findings:

| # | File | Findings | Worst |
|---|---|---|---|
| 1 | app/models/citation.rb | 10 | `chicago_citation` cyclomatic 10, MLA and Harvard 9 |
| 2 | app/models/robots_policy.rb | 6 | `directive` cyclomatic 13 |
| 3 | lib/middleware/bot_guard.rb | 5 | `call` cyclomatic 9 |
| 4 | app/models/structured_data.rb | 4 | `record` cyclomatic 11, 19 lines |
| 5 | app/models/zip_writer.rb | 3 | `check_name` cyclomatic 12 |
| 6 | app/models/page_chrome.rb | 3 | `for` cyclomatic 13 (a case over page types) |
| 7 | app/components/nexus_ccs/bulk_selection_component.rb | 3 | `rows` cyclomatic 9 |
| 8 | lib/image_dimensions.rb | 2 | `jpeg` cyclomatic 9 (a binary parser) |
| 9 | app/components/nexus_ccs/record_document_component.rb | 2 | |
| 10 | app/models/search_defaults.rb | 2 | `empty_advanced_search?` 9 |
| 11 | app/controllers/concerns/citations_page.rb | 2 | 17-line method |
| 12 | app/controllers/concerns/query_rules.rb | 2 | |
| 13 | app/models/catalog_config/facets.rb | 2 | |
| 14 | app/indexers/collections/vernon_source.rb | 2 | 30-line hash (a column map) |
| 15 | app/indexers/collections/indexer.rb | 2 | `index`, 24 lines |

Most are case statements or column maps, which read better flat than split. Every file in the list is covered at 95% or more, so
each can be refactored under test. I did not refactor any: the benefit does not justify the diff, and the largest, `emu_source`
`build_document` (50 lines), is a field map where splitting would hide the mapping. Rubocop (omakase) passes with no offences.

### Duplicated code

A scan for repeated runs of 6 or more lines found almost none in Ruby, 0 in ERB components, 5 windows in two Stimulus controllers
(`help_tip` and `list_menu`: open/close and Escape handling), and 1 in tests. The one real duplication is the three layouts
`layouts/blacklight/base`, `branded_stock` and `stock_blacklight` (about 40 shared lines of `<head>`), which exist for the two
stock record pages (ADR 0006) and go when those do.

### Dead code (`script/unused.rb`, `script/i18n_check.rb`)

| Kind | Candidates | Result |
|---|---|---|
| Stylesheets not imported | 0 | |
| Stimulus controllers nothing attaches | 0 | |
| Partials nothing renders | 0 of ours (the two record-page partials went when About this record became a component, 2026-11-11); 5 more override Blacklight views | kept |
| Components, models, helpers nothing mentions | 0 | |
| Images nothing mentions | 46 | 33 are OpenSeadragon button images (the viewer builds their names; kept); **13 removed** |
| Named routes with no helper call | 41 | all are Rails/Blacklight/Turbo routes, error pages, redirects or URLs people visit; none removed |
| Locale keys nothing uses | 6 | **6 removed** |
| Locale keys used but missing | 1 | **fixed** (a visible bug: the lists page link showed "Saved Records") |

Proof for the removals: each file name was searched across `app`, `lib`, `config`, `test`, the repository `docs` and the root; the
only hits were the `help-search-tips` word in an unrelated CSS class and in a 2026 doc; no `site/#{...}` dynamic path exists in
the app (every `image_tag`/`asset_path` of `site/` uses a literal). The locale keys have no literal or prefix reference, and the
full suite passes, with the system suite run before and after. Removed images are 940 KB: eight `help-*.svg`, `campus-students.jpg`,
`hero-parkville.jpg`, `icon-arrow-faq.svg`, `icon-chevron.svg`, `icon-search-button.svg`.

Not removed, flagged: the Gemfile has gems nothing uses today (`jbuilder`: no jbuilder views; `kamal`; `thruster` is in the
bundle but not started; `image_processing` and Active Storage are loaded but unused; `solid_cache`, `solid_queue`, `solid_cable`
are bundled but not configured). Removing a gem needs the dev team's agreement (ADR 0009) and a rebuild of the image.

### Dependencies

`bundle outdated`: 24 gems behind, all patch or minor except `json` 2.21 to 3.1, `marcel` 1.2 to 2.1, `net-ssh` 7 to 8, `prism` 1.9 to 2.1 and
`retriable` 4 to 5 (transitive, majors); Rails 8.1.4 and Blacklight 9.2.1 are current. Notable: `view_component` 4.15 to 4.20, `rubocop`
1.88 to 1.92, `kaminari` 1.2.2 to 1.3.2, `nokogiri` 1.19.4 to 1.19.6. `bundler-audit` and `brakeman` report nothing. `npm outdated axe-core`:
current (^4.13.0). Vendored JavaScript (`vendor/javascript`: Bootstrap, OpenSeadragon 5.0.1, Chart.js, Popper) is updated by hand and
has no automated check. Dependabot PRs are not touched here. `blacklight-gallery` comes from a git branch (`main`), which Bundler
will not update unless asked: pin a commit or release when one allows Blacklight 9.

### Speed of the suites

Unit and integration: 12 seconds with Solr (664 runs, parallel on 10 cores), 7 seconds without (66 skip). Under `bin/coverage`
(one process) 27 seconds. System: 123 seconds for 152 tests, one process. `bin/ci --quick` is 22 seconds; `bin/ci` adds the audits.

### Documentation

Current and linked from the README: architecture, how-to-change, configuration, CONTRIBUTING, ADRs 1 to 11, CONTEXT.md,
`ead-ccs-test/docs/*` (running, seo-and-bot-controls, performance, styling, data-model, solr-dev). Stale or contradictory, now flagged
at the top: `ead-ccs-test/docs/handover.md` (October; said Rails 8.1.3, 99 tests), `secrets.md` (AWS and Kubernetes; the app is on Azure).
Fixed: the Rails README had empty sections and a broken link. Still historical without a banner: `docs/HANDOFF.md`,
`docs/code-quality-plan.md`, `docs/css-refactor.md`, `docs/conventions.md` (describes both sites and the 2026 token files; its
"Where a change is made" table partly applies to the retired static site), `ead-ccs-test/docs/styling-inventory.md`. `script/check_docs.rb` skips these.
`ead-ccs-test/docs/jira-coverage.md` and `blacklight-features.md` were not re-verified.

## What changed

| Commit | Change | Shared source? |
|---|---|---|
| fix | `lists/index.html.erb` used `nexus_ccs.saved_records` (missing); now `nexus_ccs.lists.saved_records` | one view line |
| chore | `bin/coverage`, `script/unused.rb`, `script/i18n_check.rb`, `script/check_docs.rb` (no gem) | new files |
| chore | removed 13 unused images, 6 unused locale strings | `config/locales/en.yml` |
| chore | `config/ci.rb` (`bin/ci`) now mirrors GitHub CI, tests with and without Solr, optional `--system` | replaces the Rails default |
| test | indexers, `Collections::Indexer`, `SearchService` characterisation tests (+50 tests); `i18n_check_test` | tests only |
| docs | `docs/architecture.md`, `configuration.md`, `how-to-change.md`, ADRs 0007 to 0011, CONTRIBUTING.md, PR template, README start-here list, CONTEXT.md terms, banners on stale docs | `README.md`, `.github/pull_request_template.md` |

The README quick start was checked by `script/check_docs.rb` (every command and task it names exists), not by installing from scratch.
The locale check is in `bin/ci`; only its missing-key half is a test, because an unused key is not a defect.

## Backlog for the dev team (most valuable first)

1. **Replace `AccessPolicy` and `Sensitivity` with the DAM's classification** when the ingest exposes it (`assets_json`). Policy-critical; the seams are ready.
2. **Add `bin/ci` to the contributor routine and consider making `system` a required check.** Add an `auto-merge.yml` guard (or delete it): it merges `feature/*` branches without CI.
3. **Retire the 2026 prototype** (`docs/decoupling-from-2026.md`): delete `public/` (except `digital-assets`), `src/`, `scripts/`, `tests/`, root `ci.yml`; give `ead-ccs-test` its own `package.json` for axe-core; remove the "Generated" headers from page styles.
4. **Remove unused gems** (`jbuilder`, `kamal`, `thruster`, `image_processing` and Active Storage, `solid_*`) and the unused Puma/cable settings, after confirming they are not wanted for deployment.
5. **Bring the stale documents up to date or move them to `docs/archive/`**: `handover.md`, `secrets.md`, `HANDOFF.md`, `code-quality-plan.md`, `conventions.md`.
6. **Split `pages/static_shared.css`** (1,279 lines) and `tokens/static_site.css` by page, once the generator is retired.
7. **Share the rate limit** (`RATE_LIMIT_STORE=cache` with a shared cache, or a WAF) if the app runs more than one instance.
8. **Pin `blacklight-gallery`** to a release or commit; update the 24 outdated gems in one Dependabot-reviewed batch, starting with `view_component` and `rubocop`.
9. **Add a check for the vendored JavaScript versions**, and run `bin/ci --system` in a nightly job.
10. **Reduce `PageChrome.for`, `RobotsPolicy.directive` and `Citation` style methods** (cyclomatic 9 to 13) only when next changing them; each is fully tested.
11. **Fill or delete the empty `ApplicationJob` and `ApplicationMailer`** stubs (no jobs or mail exist; the access-request export is manual).

## Re-running the measurements

```sh
cd ead-ccs-test
bin/coverage --files          # coverage by directory and file
ruby script/unused.rb         # dead-code candidates (add --no-routes to skip the route check)
ruby script/i18n_check.rb     # missing and unused locale keys
ruby script/check_docs.rb     # docs match the code
bundle outdated; (cd .. && npm outdated axe-core)
bin/ci --system               # everything GitHub runs, plus the browser suite
```
