# Blacklight features and plugins

Configuration-only use of Blacklight 9.2.1 and its official plugins, in `CatalogController`
(`config/locales/blacklight.en.yml` for labels). No custom facet UI.

| Feature | Mechanism | Solr field(s) |
|---|---|---|
| Search fields: all, title, creator, subject | `add_search_field` (qf/pf in `solr/conf/solrconfig.xml`) | `title_tsim`, `creator_tsim`, `subject_*`, `all_text_timv` |
| Facets with "more" modal, collapse, limits, in sections | `add_facet_field ... limit:`, `group:`, built from the workbook | see `docs/data-model.md` |
| Year selectors (production date, creator birth and death) | `blacklight_range_limit` 9.3.0, `range: true` | `date_start_isi`, `creator_birth_isim`, `creator_death_isim` |
| Constraints and Start over | built in (restyled in `unimelb.css`) | n/a |
| Sort: relevance, title A-Z / Z-A, date newest / oldest | `add_sort_field` | `title_si`, `date_start_isi` |
| Per page 12 / 24 / 40 / 96 (default 40) | `config.per_page`, `default_per_page` | n/a |
| Advanced search | `config.advanced_search.enabled` | search and facet fields |
| Citation, JSON API, did-you-mean, autocomplete | built in | n/a |
| Search history (CCS-143) | Blacklight's own, as it comes: searches saved in the session and listed at `/search_history`, with Clear history and a 100-search cap. We add only the search overlay's last-5 list. Grouping by day (CCS-206) is not in the MVP, so there are no day headings | n/a |
| Bookmarks, shown as "Save / Saved" and "saved records" (CCS-46) | Blacklight's own: `BookmarksController`, `/bookmarks` routes, `Bookmark` model, the bookmark JavaScript (no page reload, updates every `data-role="bookmark-counter"`), `current_or_guest_user`, `config.add_results_document_tool :bookmark`, Clear bookmarks. We add: a minimal `users` table + `User` model (guests only, no login, no email or password), `GuestBookmarks` (the guest row is only created on the first save, so browsing writes nothing; tied to the 30-day session cookie), `NexusCcs::SaveControlComponent` (the Save / Saved toggle, a real checkbox named "Save record: <title>"), `NexusCcs::Icons::BookmarkComponent` (`config.bookmark_icon_component`), `NexusCcs::SavedBarComponent` + `saved_bar_controller.js` (the slate-teal "N saved records" block at the right end of the breadcrumb strip, rendered by both breadcrumb components, exactly as tall as the strip; on a page with no breadcrumb (home) it stays in the header top strip; `site-nav__saved`, live region), the `/bookmarks` view and `blacklight.bookmarks` wording in `config/locales/en.yml` | n/a |
| List and mosaic (masonry) views | built-in list + `blacklight-gallery` (git `main`) via `config.view.*`; grid and slideshow removed | `thumbnail_path_ssi` |

## Notes

- **Saved records / guests.** There is no login: a visitor's bookmarks belong to a `User` row (just an id and timestamps)
  that is created on their first Save and remembered in the session cookie (`blacklight_guest_user_id`, 30 days). Clearing
  cookies, or another browser or device, starts an empty list; there is no transfer between devices. Stale guest rows
  (no activity for a long time) are not pruned yet. Deploy needs `db:migrate`; the image's start command already runs `db:prepare`.
  The result cards render the control themselves (the title's own tool actions are turned off) and the record page renders it in its summary, so the control is not repeated in the hidden show-tools sidebar.

- **Results page width.** `BlacklightHelper#container_classes` makes the results page `container-fluid`
  (no max width); other pages keep the fixed container.

- **blacklight-gallery** 6.0.0 on rubygems pins `blacklight ~> 9.0.0beta1`, so the Gemfile uses its
  `main` branch (gemspec allows `~> 9.0`). Its generator also adds OpenSeadragon (IIIF viewer) and a
  jQuery CDN pin; neither is used here.
- **Digital assets.** 30 records have images (about 60 files), mapped by accession number in
  `config/digital_assets.yml` (generated from the static prototype's `ASSET_IMAGES`). The indexer
  (`Collections::DigitalAssets`) adds `thumbnail_path_ssi`, `digital_asset_paths_ssim` and
  `digital_asset_large_paths_ssim` and `has_digital_asset_bsi`; thumbnails (800 px) and large images
  (1600 px) are JPEGs in `public/digital-assets/thumbs` and `/large`, made from the originals by
  `bin/rails digital_assets:thumbnails` (needs `vipsthumbnail`; originals are not in this repo, they
  live in the static site's `public/assets/images/collections`). `config.index.thumbnail_field`
  shows them in both views (the list shows one only when a record has an asset); the mosaic shows
  a placeholder otherwise, and mosaic placeholders vary in shape so the masonry still reads as a mosaic.
  On a record's page `NexusCcs::DigitalAssetsComponent` (the show page's `document_embed_component`)
  shows the first image large under the title and the rest as thumbnails that open the large image.
  The "Digital Asset Format Type" filter lists records with assets. More assets: add
  accession numbers and file names to the YAML, make thumbnails, reindex.
- **Date quality.** `date_start_isi` has no value for about 12,700 of 41,000 records; the range facet
  leaves those out. Negative years are real BC dates (the EMu export has about 1,400, written "BC -1000"
  and parsed by `Collections::DateRange`), and no year is 0, so the histogram is wide but correct.
  Do not filter years of 0 or below.
- **JS.** chart.js and `@kurkle/color` (range-limit's dependencies) are vendored in
  `vendor/javascript`; the plugin's generator pins them to a CDN instead.
- **Facets only render when they have values.** The facets, sections and record fields now come from the
  workbooks (`docs/data-model.md`); the earlier pivot, "Record includes" query facets and contextual
  `if:` facets are no longer configured because the workbook does not define them.

## Advanced search is stock Blacklight

`/catalog/advanced` is Blacklight's own `Blacklight::AdvancedSearchFormComponent` and its own views
(`blacklight/app/views/catalog/advanced_search.html.erb`, `_advanced_search_form.html.erb`,
`_advanced_search_help.html.erb`), unmodified: config-only (`config.advanced_search.enabled`,
`copy_search_field_config_to_advanced!`, `copy_facet_field_config_to_advanced!`), the same way the rest of this
doc's features are config-only. It sits inside the site's normal header/footer layout like every other page, but
the form itself — the single "match all/any" menu, one fixed row per search field, the facet checkbox accordion,
Search + Start over — is exactly what the gem renders.

An earlier version added a dynamic row builder (must/should/must_not per row, up to 8 rows), an "Includes
any/all" toggle per facet (`f_all`), a flyout modal, and a reinstated "within search" summary. All of that was
removed (2026-10-13) to match stock Blacklight, per https://catalogue.nla.gov.au/catalog/advanced as the
reference for what "default" should look like. `test/models/search_builder_test.rb` keeps one test of
Blacklight's own `must_not` query building (a real capability of the search builder, just never exposed by the
stock form), in case a future UI needs it — nothing in this app builds a must_not clause today.

## Facets are stock Blacklight

The results sidebar renders Blacklight's own `Blacklight::FacetComponent` for every facet, and each facet is
plain config (label, group, limit, `index_range`, range limit plugin for years, one query facet for digital
assets). There is no custom facet component, filter query builder (multiple values in one facet combine the
default way: AND), `{!tag}/{!ex}` self-exclusion, or hand-built range slider/histogram. Only the styling
(`unimelb.css`) differs. `test/controllers/catalog_configuration_test.rb` guards the config.

## Record page licence hover text

The licence badge (`StockLicenceBadgeComponent`) shows the reviewed copy as hover text: "<label> means you can use this item freely."
(public domain, CC0, CC BY, CC BY-SA), "In copyright means you may be able to use this item if you seek permission." ("Copyright -
Current"), and "means you can use this item with conditions." for CC licences with NC or ND (as on the static site). "Reproduction
Licence - Current" has no hover text: the copy does not cover it, a stakeholder decision.

## Advanced search title

The one change to the stock form is its title, "Advanced search", through the locale (`config/locales/search_bar.en.yml`:
`blacklight.advanced_search.form.title` and `page_title`). The rest of the wording in the reviewed copy (description, "Enter search term",
tips, "Filters") has no locale hook in stock Blacklight and describes controls only the static form has (rows, match types, Add
filter), so it is not applied here: a decision for the product owner.
