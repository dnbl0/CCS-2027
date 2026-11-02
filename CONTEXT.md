# Collections Navigator

Search across the University of Melbourne's cultural collections. The product is the Rails/Blacklight app in `ead-ccs-test/`
(live on Azure as `ccs-web`); `public/` is the earlier static prototype of the same pages.

## Language

**Collections Navigator**:
The product's name, shown to visitors (renamed from "Cultural Collections Search" in October 2026).
_Avoid_: CCS (fine in docs and Jira, not on screen), Cultural Collections Search, Nexus

**Collection**:
One of the five museums or collections whose records are searched, such as the Grainger Museum Collection. A collection has
no page of its own: it is the results filtered by it (`collection_ssim`, see [ADR 0002](docs/adr/0002-collections-are-filtered-results.md)).
_Avoid_: landing page, museum page

**Record**:
One catalogued object, specimen, artwork or document, shown at `/catalog/:id`.
_Avoid_: item, object page, document (Blacklight's code says "document"; say record to people)

**Digital asset**:
An image, video or file attached to a record. Results show records with a digital asset unless the visitor chooses otherwise
([ADR 0004](docs/adr/0004-results-default-to-records-with-a-digital-asset.md)).
_Avoid_: media, thumbnail (a thumbnail is one size of a digital asset)

**Source system**:
The collection management system a record comes from: EMu or Vernon. Record ids start with its name (`emu-9044`, `vernon-MHM00394`).

**Filter**:
A choice that narrows the results to records with a value, shown in the filter sidebar and as a pill once applied.
_Avoid_: facet (Blacklight's word; fine in code), refinement

**Pill**:
An applied filter or search term shown above the results, removable on its own.
_Avoid_: chip, constraint (Blacklight's word in code)

**Advanced search**:
The form at `/catalog/advanced` for searching by field and combining filters.
_Avoid_: Advanced Filters (the static prototype's old name)

**Search history**:
The searches made in this browser, at `/search_history`.

**Saved records**:
Records a visitor saves in this browser without signing in (Blacklight bookmarks). Hidden unless `SAVED_RECORDS=on`
([ADR 0005](docs/adr/0005-saved-records-hidden-by-default.md)).
_Avoid_: bookmarks (on screen), favourites

**Stock record page**:
Blacklight's own record page, at `/stock/:id` and `/branded-stock/:id`, kept for two records so stakeholders can compare it with
the site's record page ([ADR 0006](docs/adr/0006-stock-record-pages-for-two-records.md)).

**Page chrome**:
The parts of the header that change with the page: the breadcrumb trail, the banner under it (search, record title or page
banner) and where the saved-records bar sits. Decided in one place, `PageChrome` (tested in `test/models/page_chrome_test.rb`).
_Avoid_: header state, layout flags

**Data model workbook**:
`CCS Field labels and filters.xlsx`: the source of truth for field labels and which fields are filters.

**Access tier**:
What a visitor may do with a record's digital assets: `open` (view and download), `view_only` (view; download on request) or
`request` (view on request and approval). Derived from the record's licence by `AccessPolicy`
([ADR 0007](docs/adr/0007-access-policy-is-derived-from-the-licence.md)). Metadata is shown on every tier.
_Avoid_: permission level, rights status

**Sensitive record**:
A record whose assets the visitor is asked about before they are shown (`Sensitivity`). The visitor's choice is kept in their
session; it never overrides the access tier.

**Guest**:
A visitor, identified only by their session cookie; there is no sign-in ([ADR 0008](docs/adr/0008-guest-users-without-login.md)).
_Avoid_: user, account

**Ingest**:
The University dev team's process that fills Solr from EMu, Vernon and the DAM. This repository's `Collections::Indexer` fills
a core from the committed CSV exports for development, CI and demos only ([ADR 0011](docs/adr/0011-solr-is-read-only-for-the-app.md)).

See [docs/architecture.md](docs/architecture.md) for how these fit together.
