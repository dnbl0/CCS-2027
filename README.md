# Cultural Collections Search - University of Melbourne

A static front-end prototype for searching and browsing the University of Melbourne's cultural collections (Grainger Museum, Medical History Museum, University Art Collection, Harry Brookes Allen Museum, Henry Forman Atkinson Dental Museum, and a few smaller collections).

**Design system**: UoM Gen 3 | **Bootstrap**: 5.3.3 (built locally) | **Hosting**: Azure Container Apps (the Rails app) | **Repository**: https://github.com/Enterprise-Services-Group/CCS-2027 (personal copy: https://github.com/dnbl0/CCS-2027)

> CCS 2027 is not connected to CCS 2026. The static prototype in `public/` is kept only because the Rails app's page styles were generated from it; see [docs/decoupling-from-2026.md](docs/decoupling-from-2026.md).

The site is a prototype driven by an in-repo dataset (735 listed records), not a live catalogue. Accessibility work has been done and checked with axe-core scans (clean apart from the items listed under [Known issues](#known-issues--follow-ups)), but the site has **not** had a formal WCAG audit or certification.

**Running the Rails/Blacklight app** (`ead-ccs-test/`) on your computer: see [ead-ccs-test/docs/running-the-app.md](ead-ccs-test/docs/running-the-app.md). Rules for Claude agents working here: [CLAUDE.md](CLAUDE.md).

---

## Contents

1. [Recent changes](CHANGELOG.md)
2. [Pages and URLs](#pages-and-urls)
3. [Repository layout](#repository-layout)
4. [Data: how records work](#data-how-records-work)
5. [Field labels and the spreadsheet](#field-labels-and-the-spreadsheet)
6. [Record page behaviour](#record-page-behaviour)
7. [Styling](#styling)
8. [Develop, test and deploy](#develop-test-and-deploy)
9. [Known issues / follow-ups](#known-issues--follow-ups)
10. [Related docs](#related-docs)

---

## Recent changes

See [CHANGELOG.md](CHANGELOG.md).

## Pages and URLs

All pages live in `public/` (the web root). They are "DC template" HTML: `{{ }}` placeholders in the markup plus a `class Component extends DCLogic` script, rendered at runtime by `public/support.js` (a generated runtime - do not edit it).

| URL | File | Notes |
|---|---|---|
| `/` | `public/index.html` | Home (reviewed copy, University components): split hero with search and the saved-records bar over the photo, an About band, then a listing of the five collections (each card links to the results filtered to that collection) plus a sixth card for all collections, and the line pointing to the University's other collections |
| `/search` | `public/search.html` | Redirect stub to `/search/search-results` (meta refresh, JS, and server redirect) |
| `/search/search-results` | `public/search/search-results.html` | Search, facets (`FACETS`), results grid/list |
| `/search/advanced-search` | `public/search/advanced-search.html` | Advanced Filters form (multi-row field search, filters, production-date range); submits to `/search/search-results`. Copy follows page 6 of the reviewed copy doc: a "Tip:" list under Search and under Filters; no filter applied by default; no separate Search help panel |
| `/search/search-history` | `public/search/search-history.html` | Search history: the searches made in this browser, grouped by day, newest first; each term runs the search again, and Clear history empties the list. Logic in `public/search/search-history.js`, from `window.CCSHistory` in `public/nav.js`. (The saved-records page was removed; saving is hidden, as in the Rails app.) |
| `/collections` | `public/collections/index.html` | Browse all collections: the shared Browse collections cards (alphabetical); each card opens `/search/search-results?collection=<Name>`. The five collection landing pages were removed (2026-10-16); their old addresses `/collections/<slug>` redirect to those filtered results |
| `/collections/record?id=<id>` | `public/collections/record.html` | Record detail and media viewer |
| `/about` | `public/about.html` | About CCS (reviewed copy): split hero, What is CCS, The journey, the Sidney Myer University Trust, How you can support, About CCS Data, then Contact and support as the University's link list. Last item of the header; the Rails app has the same page at `/about` |
| `/help` | `public/help/index.html` | Help and support: one page with the University's jump navigation ("On this page", sticky on desktop, a table of contents on phones, current section highlighted by `public/help/jump-nav.js`) and a section for each of FAQ, Indigenous Cultural Data and Access, Copyright and Terms of Use, and Contact Us (`#faq`, `#indigenous`, `#copyright`, `#contact-us`). Contact Us holds the contact details (the Contact page was folded in); `/contact`, `/help/search-tips` and `/help/indigenous-data` redirect here |

Legacy `*.dc.html` filenames (for example `Collection Search v3.dc.html`) 301-redirect to the pages above (see [Hosting](#hosting)).

---

## Repository layout

```
public/                     Deployed web root
  index.html, search.html, about.html
  nav.js                    Header behaviour: dropdown menus + mobile drawer (event-delegated; used by every page)
  search/search-results.html
  search/advanced-search.html     # advanced search form (logic in search/advanced-search-form.js)
  collections/{index.html, record.html}
  help/{index.html, jump-nav.js}
  collection-data.js        Record data -> window.CCS (single source of truth)
  blacklight-adapter.js     Optional live/mock adapter for a Blacklight JSON API (mock by default)
  support.js                DC template runtime (generated)
  image-slot.js             <image-slot> placeholder component (loaded by index.html)
  styles/                   tokens/tokens.css (the one token layer), base.css, components/*.css, pages/<page>.css, vendor/bootstrap-uom.min.css (see design.md, CSS Files Location)
  assets/                   images/collections (digital assets), data (audio/video, metadata sheets), documents
  images/                   Optimised web images and icons used by pages (home/ = Figma homepage assets, advanced/ = Advanced Filters icons)
  .htaccess                 Apache equivalent of the config/hosting.json redirects
src/partials/               Shared page chrome: header, search overlay, footer and browse-collections.html (the Browse collections cards on the Collections page). Written into the pages by scripts/sync-partials.js
src/scss/custom-bootstrap.scss   Bootstrap 5.3.3 theme source (see Styling)
tests/                      Plain-Node test scripts (see Develop, test and deploy)
config/redirects.json      Documentation-only list of legacy redirects (nothing reads it at runtime; config/hosting.json and .htaccess are authoritative)
assets/                     Source material for content: spreadsheets, CSVs, help/landing-page copy (.docx), original images. Not deployed (scripts/build-pages.js copies public/ only)
.github/workflows/          ci.yml, rails-ci.yml, auto-merge.yml, pages.yml (deploy to GitHub Pages), azure-deploy.yml, acr-push.yml
.agents/rules/              PR workflow rule for coding agents
verify-bootstrap.sh         Checks Bootstrap references in pages (run by npm test)
config/hosting.json          Clean URLs + legacy redirects; read by scripts/dev-server.js and scripts/build-pages.js
scripts/build-pages.js      Builds public/ into dist/ for GitHub Pages (base-path prefixing, /item/:code via 404.html, redirect pages); `npm run build:pages`
design.md, github.md, jira-mvp-mapping.md, BOOTSTRAP-DEPENDENCIES.md   Supporting docs
```

Notes on directories:

- `public/blacklight-adapter.js` is loaded by `search/search-results.html` and `collections/record.html`. Its default mode is `mock` (local `collection-data.js`); `?api=live` switches to the Blacklight endpoint set in the adapter. It is covered by `tests/blacklight-adapter.test.js`.

---

## Data: how records work

`public/collection-data.js` is an IIFE that sets:

```js
window.CCS = {
  records,   // id -> display-ready record (built by build()); superseded ids are non-enumerable aliases
  items,     // normalised search items (objectType, culture, img) used by search/search-results.html
  ids,       // listed record ids
  related(id, n = 4)  // related-record cards for the record page
}
```

`ITEMS` (an array of plain objects near the top of the file) is the raw data; `build(it)` turns each item into a record. `Object.values(CCS.records)` has one entry per listed record (735 today).

### Add or edit a record

1. Add or edit an object in the `ITEMS` array. Use a unique numeric `id` that is not already in `ITEMS` or in `SUPERSEDED` (ids in use today: 1-238, 10001-10250, 20001-20250, 50001-50007, 60001-60008).
2. Use the item keys that `build()` reads, for example: `title`, `collection` (one of the constants at the top, e.g. `MHM`, `UAC`, `GMC`), `objectType`, `date`/`dateStart`/`dateEnd`, `creator`, `creatorRole`, `associatedEntity`, `place`, `description`, `series`, `material`, `dimensions`, `inscription`, `language`, `culturalAffiliation`, `accession`, `named`, `access`, `classification`, `subject`/`subjects`, `relatedParent`/`relatedChild`/`relatedRecord`, `copyright`, `creditLine`, `licence`, `advisories`, `img` or `images`.
3. Leave a field out and it is not shown; no placeholder is rendered.
4. Run `npm test`. `collection-data.test.js` checks unique ids, non-empty titles, that every field label is one of the specification labels, and that referenced `/assets` files exist.

### Superseded records (`SUPERSEDED`)

Some early prototype stubs duplicate a fuller record. `SUPERSEDED = { oldId: canonicalId, ... }` folds them: `records[oldId]` still resolves (old links keep working) to the canonical record, but the old id is not enumerable, so it is not listed or counted twice. To retire a duplicate, add `oldId: canonicalId` to the map; the old item is dropped from `ACTIVE`.

### Digital assets (`ASSET_IMAGES`, `ASSET_AV`)

- `ASSET_IMAGES` maps a record id to a list of file names in `public/assets/images/collections/` (the filename stem is the accession number with `.` replaced by `_`; numbered suffixes are extra views). Files are URL-encoded and served from `/assets/images/collections/`.
- `ASSET_AV` maps a record id to audio/video objects `{ kind: 'audio'|'video', src, type, label }` with files in `public/assets/data/`. They play in the media viewer after any images.
- Records without an `ASSET_IMAGES` entry fall back to the web image named by `img` (or `images`) in `public/images/`.
- Add the file under `public/assets/...` first (not the top-level `assets/`, which is not deployed), then add the mapping.

---

## Field labels and the spreadsheet

Field labels, sequence numbers, filters and mandatory/optional rules follow the two workbooks: `CCS Field labels and filters.xlsx` in the repo root (the source of truth for CCS Field Labels on record pages and CCS Filters in search results and advanced search) and `assets/CCS Data inventory - final.xlsx`, extracted to `data-model/` and enforced by `tests/data-model.test.js`; see `docs/data-model.md`.

- Record page fields: the `f` array in `build()` in `public/collection-data.js` (`[seq, label, lines]`). Rights fields (16, 17, 29) come from the `rights` array; media metadata (Title, Format, Licence type, Terms of use, Advisory ...) from `media`.
- Filters: the `FACETS` array in `public/search/search-results.html` (group, key, title, kind).

### Field mapping (spreadsheet "#" and Display Field to site label)

| # | Spreadsheet field | Site label / location |
|---|---|---|
| 1 | Title | Page heading (`title`) |
| 2 | Object Type | Object type |
| 3 | Date | Date |
| 4 | Creator | Creator |
| 5 | Associated Entity | Associated entity |
| 6 | Place | Place |
| 7 | Description | Description |
| 8 | Series | Series |
| 9 | Editions | Editions (no record populates it yet) |
| 10 | Material | Material |
| 11 | Dimensions | Dimensions (H x W x D) |
| 12 | Inscription | Inscription |
| 13 | Language | Language |
| 14 | Cultural Affiliation | Cultural affiliation |
| 15 | Accession Number | Accession number |
| 16 | Copyright | Copyright (rights block) |
| 17 | Credit Line | Credit line (rights block) |
| 18 | Named Collection | Named collection |
| 19 | Collection | Collection |
| 20 | Access | Access |
| 21 | Classification | Classification |
| 22 | Subject | Subject |
| 23 | Source URL | Source URL (no record populates it yet) |
| 24 | Related Parent Record | Related parent record |
| 25 | Related Child Record | Related child record (no record populates it yet) |
| 26 | Related Record | Related record |
| 27 | Licence Type | Licence type (media metadata, records with digital assets) |
| 28 | Advisory | Advisory (media metadata) |
| 29 | Terms of Use | Terms of use (rights block and media metadata, records with digital assets) |
| 30 | Producer | Producer (no record populates it yet) |

Filter groups in the spreadsheet map to `FACETS` groups in `search/search-results.html`: Collection details, Creator, Object, Subject / topic, Copyright & advisory, Access, Media type.

---

## Advanced Search

`public/search/advanced-search.html` is a stand-alone form built from the Figma Advanced Filters frames, with the copy from page 6 of the reviewed copy doc (description, "Enter search term", the Search and Filters "Tip:" lists; no filter category applied until the user adds one; the separate Search help panel was removed). Markup uses the reusable classes in `public/styles/pages/advanced-filters.css` (`.ccs-banner`, `.ccs-page`, `.ccs-combo`, `.ccs-input`, `.ccs-date` / `.ccs-cal`, `.ccs-btn`, `.ccs-delete`, `.ccs-adv__tip`, `.ccs-errors`). The Rails app's Advanced Search is stock Blacklight and only shares the title. Its logic lives in `public/search/advanced-search-form.js` (plain JS, no framework; option lists and counts are built from `window.CCS.items`) and is made of three small components: `Select` (single-select combobox/listbox), `Multi` (checkbox menu, used by filter values and "Add filter") and `DateField` (typed date + calendar popover). Keyboard: Arrow keys, Home, End, Enter, Space, Esc and Tab; menus close on selection (single), Esc, outside click or re-activating the field, and multi-select menus stay open while ticking. Search rows range from 1 to 8 (the last row cannot be deleted). Dates accept digits and `/` only (`dd/mm/yyyy` or a year; a leading minus means BCE), must lie between the earliest and latest dates in `window.CCS.items`, and an end date cannot precede the start date; invalid input shows an error beside the field and in a summary at the top of the form. It is a plain GET form that opens the results page, `search/search-results.html`, with these URL parameters (the results page parses them in `parseAdvancedParams`):

| Parameter | Meaning |
|---|---|
| `clause[i][field]` | `all_fields`, `title`, `creator`, `subject` or `description` |
| `clause[i][op]` | `must` (contains all), `should` (contains any) or `must_not` (does not contain) |
| `clause[i][query]` | search text; `"quotes"` make an exact phrase |
| `f_inclusive[key][]` | filter values where ANY may match; `key` is `collection`, `type`, `creator`, `licence` or `access` |
| `f[key][]` | filter values where ALL must match |
| `range[year][begin]`, `range[year][end]` | production year range (the form sends the year of the chosen date) |
| `sort` | `relevance`, `year-desc`, `year-asc` or `az` |

Rows combine as: every `must` row matches, at least one `should` row matches (if any exist), and no `must_not` row matches. The results page shows each row and filter as a removable chip, and its "Advanced Search" button re-opens the form pre-filled with the current search (`advancedFormHref`). Empty rows are not sent, so URLs stay short.

## Record page behaviour

`public/collections/record.html?id=<id>`:

- Reads `window.CCS.records[id]`. An unknown or missing id shows "Record not found" and sets that as the document title. A found record sets the title to `<record title> - Cultural Collections Search - University of Melbourne`.
- Only the **Contact us** button opens the request dialog. Tabs: General enquiry, Request to use, Request to view. The dialog traps focus, closes on Esc, and returns focus to the opener. Submitting only shows a confirmation; nothing is sent anywhere.
- Media viewer shows images, audio and video from `slides`, with thumbnails and a metadata sidebar. The viewer handles keyboard shortcuts only while it has focus or is full screen (see the script in `record.html` for the exact keys).
- "Copy persistent link" and citation formats are generated from the record.

---

## Styling

- **Bootstrap 5.3.3** is compiled locally from `src/scss/custom-bootstrap.scss` (sharp corners, no shadows, UoM colours) into `public/styles/vendor/bootstrap-uom.min.css`. This file is committed because the deploy runs no Sass build. Rebuild with `npm run build:css` (`build:css:dev` and `watch:css` write an unminified `bootstrap-uom.css`). After Sass compiles, `scripts/purge-css.js` removes every rule whose classes appear nowhere in the pages or scripts (the committed file is about 26 KB instead of 227 KB); **after adding a Bootstrap class to a page, run `npm run build:css` and commit the result**, otherwise the class has no CSS. Every page links the compiled file; only `index.html` also loads the Bootstrap JS bundle from jsDelivr (version-pinned with an SRI hash).
- **Live CSS**: everything under `public/styles/`: `tokens/tokens.css` (primitive, semantic and component tokens; see docs/design-tokens/README.md, including the Figma export), `base.css`, `components/` (shared pieces such as `ccs.css`, `header.css`, `collection.css`) and `pages/<page>.css`. Layout rules are in design.md and enforced by `tests/stylesheet-structure.test.js`.
- **Page styles (no inline styles)**: each page links its own `public/styles/pages/<page>.css` (class rules, scoped by the `page-<page>` class on `<body>` so they win over shared component CSS the way the old inline styles did) (shared pieces live in `public/styles/components/`, element defaults in `base.css`, colours in `tokens/`). Do not add `style=""` attributes or `<style>` blocks; add a class and a rule instead. For a value that only the page logic knows, set a custom property inline (`style="--dyn-height:{{ b.h }}"`) and use `var(--dyn-height)` in the stylesheet.
- **Content templates (Matrix patterns)**: `public/styles/components/content-templates.css` holds the components modelled on the University's Matrix CMS content templates (unimelb.edu.au/web/matrix-cms/content-templates and /styling-content): `ct-listing` (Page Listing: image or text lists, `--alt` grey band), `pathfinder` (the Design System Pathfinder: `grid grid--cols-3|4 grid--collapsed` of `pathfinder` tiles with `--alt` and `--inverse` modifiers, the footer arrow as the title icon), `contact-box`, `notice` (`--warning`, `--success`), `side-nav`, `def-table`, `contact-cards`, `steps-list`, and the help/collection layouts (`help-layout`, `collection-layout`). Used by Browse collections, the five collection pages, Help and Indigenous data. Reuse these before writing new page CSS; values (type sizes, colours) were measured from the Matrix pages.
- **Record media access rules**: `webAccess`, `accessMessage`, `viewRestricted`, `usageNotice` and `caption` are computed in `public/collection-data.js` (see `jira-mvp-mapping.md`, CCS-27/45/50/68/69). Licence types live in the `LIC` table there; `Not licensed` hides the media and offers a request to view.
- **Tests**: `npm test` also runs `tests/image-aspect.test.js` (needs playwright-core and Chromium; skipped otherwise). Request types, the PDF viewer, the Theme filter and recent searches are described in `jira-mvp-mapping.md`.
- **Accessibility**: `tests/accessibility.test.js` runs axe-core (WCAG 2.1 A/AA) plus 320px reflow and title checks; keep it passing. The manual checklist is in `jira-mvp-mapping.md` (WCAG 2.1 AA pass). Do not claim conformance without a formal audit.
- **Fuzzy and semantic search**: `public/search/smart-search.js` (loaded by the search page) provides fuzzy, prefix and thesaurus-based matching with no backend; edit the `SYNONYMS` and `BROADER` tables there to teach it new vocabulary. `tests/smart-search.test.js` checks it against the catalogue. See `jira-mvp-mapping.md`.

- **Filters modal**: the search page's Filters panel follows the Gen 3 Modal component (white panel, navy 80% blanket, Fraunces heading, top-right Close with a visible label). It adds a "Find a filter" box, a removable "Selected" chip list and a live "Show N records" button, with the header and footer fixed while the filters scroll. Its styles are the `search-results-filters-title__*` and `filters-*` rules in `public/styles/pages/search-results/ (split by component: layout, results, toolbar, banner, flyout, filters, facet-rail, pagination, pills)`.
- **Mobile header and menu** (1023px and below): one 96px row (logo block with a 1px divider, site name, Menu button with a 32px icon over a 14px label), measured from the UniMelb mobile header (study.unimelb.edu.au). Menu opens a right-hand drawer (390px at most, page dimmed behind) with search, 63px rows (18px/600, light-blue right chevron for sub-menus) and the UniMelb audience links (14px sage uppercase). A row with a sub-menu drills in: a Back row, the section link, then its links indented 32px. The Back row is added by `public/nav.js`; styles are in `public/styles/home.css`.
- **Search bar collection menu**: the "All collections" menu sits left of the search button on the homepage (`public/search-bar.js`) and the results page; choosing a collection searches only that collection (`?collection=` in the URL). The older `scope` URL parameter (title, creator, subject) still works for advanced search links but has no menu. `/help` is one page of sections (`help-section`: a heading, a description and a list of sub headings with descriptions); Search tips and Indigenous data have pages of their own.
- **Class naming**: `block__element` (BEM style), where the block is the nearest section, form or id and the element describes the thing (`__heading`, `__item-link`, `__button-clear-all`); repeated look-alikes with different styling get `--v1`, `--v2`. Names are labels for humans; do not rely on them from scripts.
- **Components** (plain CSS classes + static markup, no build step): `home.css` defines **Navigation** (`.ccs-nav--header`, `.ccs-nav--footer`) and **Section** (`.ccs-section--hero | intro | cards | help | faq`, plus the shared `.ccs-link` and `.ccs-acc` accordion). The header/footer markup is repeated in every page (there is no include mechanism), so a change must be made in all of them; `nav.js` provides the dropdown and drawer behaviour. `advanced-filters.css` defines the form components listed under Advanced Search. Hidden/shown state of menus is driven by `aria-expanded` and CSS rather than the `hidden` attribute where the DC template layer could re-render the markup.
- **Fonts**: Fraunces (headings), Source Sans 3 (body) and Source Code Pro (code) from Google Fonts. The homepage and Advanced Filters pages request Fraunces with its SOFT/WONK axes (the Figma heading settings); the homepage matches the families and weights loaded by unimelb.edu.au.
- Bootstrap's `!important` utilities can override same-named custom classes; check for collisions when naming new classes.

Design tokens and rationale: see `design.md`. Bootstrap details: `BOOTSTRAP-DEPENDENCIES.md`.

---

## Develop, test and deploy

```bash
npm ci            # installs bootstrap, sass and playwright-core (dev dependencies only)
npm run build:css # rebuild public/styles/vendor/bootstrap-uom.min.css
npm test          # full check, see below
python3 -m http.server 8933 --directory public   # local server (as in .claude/launch.json)
```

Clean URLs (`/search/search-results`, `/collections/record`) only resolve on a host that applies `config/hosting.json` or `.htaccess`; with a plain static server use the `.html` paths.

### What `npm test` runs

1. `build:css` - compiles Bootstrap (fails on Sass errors).
2. `verify-bootstrap.sh` - for each page referencing Bootstrap, checks that the compiled `bootstrap-uom.min.css` exists (or that any CDN reference is version 5.3.3 with SRI).
3. `tests/blacklight-adapter.test.js` - default mode is `mock`, request-parameter building and document transformation.
4. `tests/page-integrity.test.js` - every `public/**/*.html` has a `<title>` and `lang`, no merge-conflict markers, and every local `href`/`src` resolves (clean-URL forms like `/search/search-results` resolve to `.html`/`index.html`). Broken css/js/page links fail; broken image links only warn.
5. `tests/collection-data.test.js` - loads `collection-data.js` in a bare sandbox; checks unique ids, titles, that field labels come from the specification list, and that `/assets` media files exist.
6. `tests/no-inline-styles.test.js` - fails if a page contains a `<style>` block, a `style-hover` attribute or a `style` attribute that is not a pure CSS-custom-property pass-through.
7. `tests/advanced-filters.test.js` - browser test (playwright-core with a Chromium build) of the Advanced Filters page: responsive layout at 1440 and 390px, dropdown keyboard behaviour and ARIA roles, multi-select and Add filter, row management limits, submission URL, pre-fill and Reset, and date-range validation. It starts its own static server. If no Chromium is found it prints `SKIP` and passes; set `PLAYWRIGHT_CHROMIUM_PATH` or run `npx playwright-core install chromium` to enable it locally.

**Warnings policy**: failures exit non-zero and fail CI. Warnings (printed as `WARNING:`) are informational and never fail the build; they track open data/content gaps (see Known issues). Current output: 0 failures, 5 warnings (no `<h1>` in `search.html`; the four unpopulated spec fields).

### CI and merge workflow

- `.github/workflows/ci.yml`: the checks for the static prototype in `public/` (Node 20, `npm ci` or `npm install`, Chromium for the browser tests, then `npm test`). It runs only when the prototype's own files change.
- `.github/workflows/auto-merge.yml`: pushes to `feature/**`, `bugfix/**` or `enhance/**` that change html/css/js/md files and have 3+ commits or 2+ changed files open (or reuse) a PR against `main`, run basic documentation/structure checks, approve it, and squash-merge it. It does not run `npm test` itself. Auto-approval only works if the repository setting **Settings > Actions > General > "Allow GitHub Actions to create and approve pull requests"** is enabled; otherwise the approve step logs a warning and the job continues to the merge step. See `github.md` and `.agents/rules/pr-workflow.md`.
- `.github/workflows/rails-ci.yml`: Rails tests, system tests and rubocop. `rails` and `system` must pass before a pull request is merged.

### Hosting

The Rails app is deployed to Azure Container Apps (see `.github/workflows/acr-push.yml`, `azure-deploy.yml` and `infra/azure/`). The static prototype in `public/` is no longer published: the GitHub Pages workflow was removed (see `docs/decoupling-from-2026.md`). `scripts/build-pages.js` still builds it into `dist/` for local use.

- `scripts/build-pages.js` prefixes links with the Pages base path, serves `/item/:code` through `404.html` and writes redirect pages for the legacy URLs.
- `config/hosting.json`: `cleanUrls: true`, `trailingSlash: false`, and 301 redirects from the legacy `*.dc.html` names and from `/search` and `/search.html` to `/search/search-results`. It is the redirect configuration: `scripts/dev-server.js` and `scripts/build-pages.js` read it.
- `public/.htaccess`: the Apache equivalent (redirects plus clean-URL rewrites) for hosting on Apache.
- Local preview: `PORT=3000 node scripts/dev-server.js`, then open `http://localhost:3000/about.html` (any page).

### Generated files and the Rails app

Some files are written by scripts; edit their source, then run the script (`npm test` fails if a copy is stale):

| Edit | Run | Writes |
|---|---|---|
| `src/partials/*.html` (header, search overlay, footer, browse-collections) | `npm run sync:partials` | the header, overlay and footer of every page in `public/`, and the Browse collections cards on the Collections page |
| `public/styles/tokens`, `components`, `pages` and `public/images` | `npm run sync:rails` | the Rails copies in `ead-ccs-test/app/assets` (no longer checked by `npm test` or CI; the Rails copies are now edited in the Rails app, see `docs/decoupling-from-2026.md`) |

`npm run lint` runs ESLint and Stylelint. The Rails app and the plan to keep both
codebases clean are described in `ead-ccs-test/README.md` and `docs/code-quality-plan.md`.

---

## Known issues / follow-ups

- **Accession numbers**: 15 of 735 records have no accession number (the data owner needs to supply them). `npm test` reports `accession number present on 720/735 records`.
- **Unpopulated spec fields**: Editions, Source URL, Related child record and Producer are supported by `build()` but no record sets them (reported as test warnings).
- **`search.html`** redirect stub has no `<h1>` (test warning).
- **Hosting behaviour unverified**: the redirects in `config/hosting.json` are applied by `scripts/build-pages.js` for GitHub Pages; check them on the live site after changing them.
- **Thin audio/video data**: only two audio/video items exist, so the sound-recording and film browse tiles map to small keyword searches.
- **Object type facet is long**: object types are free text (about 370 distinct values), so the Object type facet is long and uneven.
- **Accessibility**: axe-core scans of the pages were clean except for the items above; there has been no formal WCAG audit, manual screen-reader pass or certification.
- **Data is a prototype snapshot**: records are hand-maintained in `collection-data.js`; the Blacklight adapter's live mode is not part of the tested flow.
- **Jira mapping**: several requirement rows in `jira-mvp-mapping.md` are marked as not re-verified.

### Free catalog API (2026-10-04)
- `api/catalog.js` is a serverless function that serves `/catalog.json` and `/catalog/:id.json` in the Blacklight JSON shape (see `jira-mvp-mapping.md`). It is not deployed: GitHub Pages hosts static files only, so the results page defaults to the local catalogue and `npm run dev` serves the function for local use.

### Search acceptance criteria (2026-10-04)
- CCS-158: a "Did you mean" notice appears above results for misspelt or partial words and runs the corrected search.
- CCS-27: the record page Copyright box lists accession number, caption (digital assets only), credit line and copyright.
- CCS-116: whole-phrase meanings in `smart-search.js` (`PHRASES`).

### Search results banner and sticky tools bar (2026-10-04)
- Fix: the search form now lives permanently in the banner. The sticky bar holds only the tools plus a compact search box that appears when stuck, so its height no longer flips between a tall and a short layout while scrolling. The smart-search notices sit in their own full-width row (`.search-results-notices`) above the results grid.
- The `.ccs-hero__search` layout (form with a link stacked under it) lives in `public/styles/components/hero-search.css`, loaded by the homepage and the search results page.
- The results page banner is now compact (title plus a "N results for “query”" line). The search form sits inside the banner on the navy strip.
- Below it, one sticky `.search-results-bar` holds Sort, Filters, the Digital asset switch, the view toggle and Save this search. An IntersectionObserver sentinel adds `is-stuck` once the banner scrolls away. When stuck, the search box stays visible next to the tools on desktop and tablet.
- On phones the bar stacks: search, then Sort | Filters, then Digital asset | view | Save (icon only). When stuck it shrinks to the search row plus Sort | Filters | Digital.
- The per-page selector moved to sit above the pagination. CSS lives in `public/styles/pages/search-results/ (split by component: layout, results, toolbar, banner, flyout, filters, facet-rail, pagination, pills)`.
- Follow-up: banner and search strip padding increased; the search form reuses the homepage `ccs-hero__search` wrapper (full width, Advanced Search underneath). When stuck, Advanced Search is hidden, the bar is one row from 1280px and two rows below, and all controls are 48px tall.
- Scope menu and suggestions now open over the sticky bar (banner z-index above it).
- The banner's Advanced Search link is now a toggle ("Advanced Search" / "Hide advanced search") that opens the advanced form inline: an iframe of `/search/advanced-search?embed=1` pre-filled with the current search, auto-sized through a `postMessage` of its height. In `?embed=1` mode the page hides the header, breadcrumbs, banner, help and footer and uses compact spacing (`html.is-embed` rules in `styles/advanced-filters.css`); submitting targets the top window.
- Advanced Search page: heading renamed "Advanced Search" (banner, breadcrumb, test), "Add filter" label is light on the dark desktop field (dark on the sage phone field), and Reset / Search sit at the right.

---

## Related docs

- `design.md` - tokens, typography, components, IA notes
- `BOOTSTRAP-DEPENDENCIES.md` - Bootstrap build and usage
- `github.md` - source-repo sync notes
- `jira-mvp-mapping.md` - 2026 MVP requirements mapping

For Gen 3 guidance see https://designsystem.web.unimelb.edu.au/.

© 2026 The University of Melbourne. All rights reserved.

**Last updated**: 2026-10-03
