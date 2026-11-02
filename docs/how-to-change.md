# How to change X

Recipes for the changes most often asked for. Each says where the change goes, what else must follow and which test will tell
you if you missed it. Paths are under `ead-ccs-test/` unless they start with `docs/`. Run `bin/ci` before opening a pull request
([CONTRIBUTING.md](../CONTRIBUTING.md)). How the parts fit is in [architecture.md](architecture.md).

## Add a field to the record page

The fields and their order come from the project workbook, not from code.

1. Update `CCS Field labels and filters.xlsx` (repository root) and run `python3 script/extract_data_model.py` (needs
   `pip install openpyxl`). It rewrites `config/data_model/*.json`; commit them.
2. In `config/data_model/solr_mapping.yml` give the new row a `solr:` field (add `index: true` to show it in the results list
   too), or a `gap:` saying why there is no data yet.
3. If the field needs a new Solr field, write it in the indexer: `app/indexers/collections/emu_source.rb` and `vernon_source.rb`
   (the production ingest is the dev team's: ask them for the field, see [ADR 0011](adr/0011-solr-is-read-only-for-the-app.md)).
   Add the field to `solr/conf/schema.xml` if no dynamic field pattern (`_ssim`, `_tsim`) matches its name.
4. Reindex (`FORCE=1 bin/rails collections:index`).

`CatalogConfig::RecordFields` then shows it with the workbook's label. `test/models/data_model_test.rb` fails if the mapping, the
workbook and the indexers disagree, and says which.

## Add a filter

Same route as a field: the workbook's CCS Filters sheet, `script/extract_data_model.py`, then `filters:` in `solr_mapping.yml`.
`CatalogConfig::Facets` builds the facet (a year range, a checkbox list or a browsable A to Z list, by the sheet's type). The
section titles are in `config/locales/blacklight.en.yml`. A filter with a `gap:` is shown with a "not available yet" note and is
never sent to Solr. Check the Advanced search page as well as the results: both show every filter.

## Add a help topic

Help is one page, `/help`, with a section per topic.

1. Add a `new("key", "Title", "One-line description")` to `HelpTopic::ALL` (`app/models/help_topic.rb`). The key is the anchor
   (`/help#key`) and the topic appears in the header's Help menu automatically.
2. Write the section in `app/views/pages/help.html.erb` with `id="key"`; the jump navigation beside it reads `HelpTopic.all`.
3. Update `test/models/help_topic_test.rb` and `test/controllers/pages_test.rb`, which list the topics.

## Change a licence tier

The tier of a record (`:open`, `:view_only`, `:request`) is derived from its licence in `app/models/access_policy.rb`: change
`TIER_BY_LICENCE` (keys are lower case) or `WITHHELD`. Nothing else reads the licence. Then update `test/models/access_policy_test.rb`
(it has one test for each licence and its tier, in `EXPECTED`). The record page, results, downloads, structured data and sitemap follow the
tier, so run the whole suite. The reasoning is in [ADR 0007](adr/0007-access-policy-is-derived-from-the-licence.md); a licence
change is a policy decision, so confirm it with the collections team.

## Add a page to the sitemap

`Sitemap::STATIC_PATHS` (`app/models/sitemap.rb`) lists the public pages; the record pages are added from Solr. Add the path there
and to `test/models/sitemap_test.rb`. If search engines should not index the page, say so in `RobotsPolicy`
(`app/models/robots_policy.rb`) so the header, the meta tag and the sitemap agree: a personal or action page goes in
`RobotsPolicy::PERSONAL_PREFIXES` (`noindex, nofollow`, and disallowed in `robots.txt`). Add the page to
`test/integration/seo_files_test.rb`.

## Add a locale string

Every sentence a visitor reads that is not content from the records goes in `config/locales/en.yml` under `nexus_ccs:` (or the
page's own namespace) and is used as `t("nexus_ccs.area.key")` in a view or component. Use the full key (a lazy `t(".key")`
is used in only one view, `catalog/_country_acknowledgement`, and the check works out its path from the file). SEO text is in `config/locales/seo.en.yml`; Blacklight's own wording is overridden in
`blacklight.en.yml`. Run `ruby script/i18n_check.rb`: it fails on a key you use but did not add, and lists keys nothing uses. A
`t("prefix.#{variable}.title")` marks everything under `prefix.` as used, so keep the dynamic part to the end of the key.

## Add a Stimulus controller

1. Create `app/javascript/controllers/name_controller.js` (copy `truncate_controller.js` for the style). The importmap loads every
   file by name (`config/importmap.rb` pins the folder, `controllers/index.js` registers them), so there is nothing to register.
2. Attach it in a template with `data-controller="name"` (a file `my_thing_controller.js` is `my-thing`).
3. The page must still work without JavaScript: render the full content and let the controller enhance it.
4. Add a journey in `test/system/` if it changes what a keyboard or screen reader user can do (the axe checks in
   `test/system/accessibility_test.rb` visit the main pages).

`ruby script/unused.rb` reports a controller nothing attaches.

## Add a stylesheet

Create it in `app/assets/stylesheets/components/` (or `pages/`) with its own prefix on every class (BEM, `block__element--modifier`)
and add one `@import url("components/name.css");` to `application.css`, in the order the cascade needs. Use the tokens in
`tokens/` rather than raw colours and sizes ([styling.md](../ead-ccs-test/docs/styling.md)). `test/lib/asset_bundle_test.rb`
checks that the imports flatten into one file for production.

## Add a migration safely

1. `bin/rails generate migration AddThingToLists thing:string`. Read the file it wrote; `db/schema.rb` changes with it and both
   are committed.
2. **The container runs `db:prepare` every time it starts** (the Dockerfile's command), so a migration runs on deploy, while
   the old version may still be serving. Make it safe for both versions: add a column or table first (nullable, or with a
   default), deploy, and only in a later change remove or rename what the old code used.
3. Only the app's own tables (`users`, `lists`, `saved_searches`, `access_requests`, Blacklight's `searches` and `bookmarks`) are
   in Postgres. Never put record data there: records live in Solr.
4. Add `validates` and a model test; set a limit on anything a visitor can fill (see `List::MAX_PER_USER`).
5. Run `bin/rails db:migrate:redo` once to prove it can go back, then `bin/rails test`. Use `DB_SUFFIX` in a second worktree so
   the migration does not run against another checkout's database.

## Add a setting or feature flag

Read it from the environment where it is used (`BotControls.on?("NAME", default)` for a switch), add a row to
[configuration.md](configuration.md) in the same change (`ruby script/check_docs.rb` fails otherwise), and test both values with
`with_env` (`test/support/env_override.rb`).

## Add a gem

Do not, without the team's agreement: see [ADR 0009](adr/0009-no-new-gems-without-a-decision.md).
