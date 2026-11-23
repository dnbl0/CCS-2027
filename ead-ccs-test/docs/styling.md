# Styling

How the app's CSS and JavaScript are organised, and how to run them in development.

## Layout

```
app/assets/stylesheets/
  application.css           manifest: the only file the layout links; @imports the rest in order
  bootstrap-uom.scss        entry point for the themed Bootstrap build (compiled by dartsass-rails)
  _bootstrap-uom-variables.scss   Bootstrap Sass variables (UoM colours, square corners, no shadows)
  fonts.css                 self-hosted Source Sans 3 and Fraunces (files in app/assets/fonts)
  tokens/primitives.css     tier 1 design tokens: raw values, --ccs-<category>-<name>
  tokens/semantic.css       tier 2 design tokens: roles (text, surface, border, action, focus)
  unimelb.css               theme: maps tokens onto --bs-* / --bl-* and restyles Blacklight pages
  components/               one file per component, named after it (site_header.css ...)
app/components/nexus_ccs/   ViewComponents, each with the CSS file of the same name
app/javascript/controllers/ Stimulus controllers (site_header, search_overlay, dialog)
vendor/javascript/          vendored ES modules pinned in config/importmap.rb (no CDN)
```

Load order is vendor (Bootstrap, Blacklight), fonts, tokens, theme, then components.

## Conventions

- **Tokens first.** Use `--ccs-*` tokens, preferring semantic ones. Raw colours, font sizes and
  spacing in component CSS are a smell. Bootstrap's Sass variables must be literal colours, so
  `_bootstrap-uom-variables.scss` repeats a few values; `test/assets/bootstrap_theme_tokens_test.rb`
  keeps them in step with the tokens.
- **One component, one file.** Each block gets `components/<block>.css` (snake_case file, kebab-case
  class): `site_header.css`, `site_footer.css`, `search_banner.css`, `breadcrumb_bar.css`.
- **BEM names, no page prefixes.** Blocks are nouns for the thing (`site-header`, `site-nav`,
  `site-footer`, `search-banner`, `breadcrumb-bar`, `arrow-link`); elements use `__`, variants `--`.
  Don't name classes after pages or Figma frames.
- **Use Blacklight's classes where Blacklight owns the markup** (`.facet-limit`, `.document`,
  `.search-btn` ...) rather than replacing its views. Replace markup only through Blacklight's
  extension points (`config.header_component`, `shared/_footer`, document components).
- **Behaviour in Stimulus**, not global scripts. Controllers declare their targets and actions in
  the markup (`data-controller`, `data-action`).
- **Don't rely on `form_with ..., role:`**: `form_with` drops it. Use `html: { role: "search" }`.
- **Layers.** Use `--ccs-z-*`. The header sits above Bootstrap's sticky and fixed layers and below modals.

## Static site class names

Components ported from the static CCS prototype were renamed; the old names are gone.

| Static | Rails |
|---|---|
| `.ccs-nav--header`, `__brand`, `__top`, `__bottom`, `__title` | `.site-header`, `__brand`, `__utility`, `__bar`, `__title` |
| `.ccs-nav__search`, `__menu` | `.site-header__search-toggle`, `__menu` |
| `.ccs-nav__primary`, `__trigger`, `__panel*`, `__back`, `__drawer-*` | `.site-nav`, `__trigger`, `__panel*`, `__back`, `__search`, `__audience` |
| `.ccs-nav--footer`, `.ccs-foot__*` | `.site-footer`, `.site-footer__*` |
| `.ccs-link` | `.arrow-link` |
| `.uom-search-popover*` | `.search-overlay*` |
| `.page-breadcrumbs`, `.page-local-history*` | `.breadcrumb-bar`, `__trail`, `__item` |
| `.search-results-banner`, `.page-banner__*`, `.ccs-searchbar*` | `.search-banner`, `__title`, `__summary`, `__form` (Blacklight's own form) |

## Development

```sh
bin/dev                 # Rails on :3002 (override with PORT) and the Sass watcher
bundle exec rails dartsass:build   # one-off build of app/assets/builds/bootstrap-uom.css
bundle exec rails test
```

`app/assets/builds` is git-ignored; `assets:precompile` and `test:prepare` build it.
`CCS_STATIC_URL` is the base URL of the static site that hosts Help and Contact; when unset the
header omits those items (in development it defaults to `http://localhost:3000`).

## Headings, links and controls (one style for every page)

- **Heading scale** (`tokens/semantic.css`, `--ccs-heading-*`): a page section h2 is the home page's section heading (Fraunces
  40px, 30px on a phone); a panel, form section or card-box h2 is Fraunces 24px; a sub-heading in running text (h3 on Help,
  Explore group titles) is Source Sans 3 600 at 24px; a card or list item title is Source Sans 3 600 at 18px. Use the tokens, not sizes.
- **In-content link** (`components/links.css`): link blue, underlined at rest, a 2px line and the hover blue on hover, the site
  focus ring. Add the class `ccs-text-link`, or leave a link in a paragraph, list item or `dd` of `<main>` without a class. Arrow
  links, links that stretch over a whole card, the header, footer and breadcrumb links and the Help "On this page" navigation are
  separate patterns.
- **Buttons** follow the Gen 3 design system's buttons (designsystem.web.unimelb.edu.au/style-guide/buttons): primary `btn-primary`
  (cyan, the light cyan on hover), secondary `btn-secondary` (sage), tertiary `btn-outline-primary` (navy words in a 1px navy outline, the
  light cyan on hover, never filling navy), all 18px Source Sans 3 600, 12px by 16px, square (`unimelb.css`); and the text button,
  `text-button` (`components/text_button.css`: link blue, no underline until hover, its icon 20px after its words). Use buttons sparingly,
  one main action a view. Never an icon on its own: every button has its words (an icon may follow them).
- **Controls** use the body font (`unimelb.css`): buttons and inputs would otherwise be the browser's system font. The one
  exception is the "all / any" menu in the Advanced search heading, which is set in the heading's serif by the design.
- **Explore tiles** (`components/explore.css`, docs/explore.md): the face of a collection tile with no picture is one of six tints, `--ccs-explore-tint-1..6`
  in `tokens/semantic.css`, mapped to palette tokens, with navy text. A new tint is a new token there, not a hex in the component.
- **Colours, radii and sizes** come from `--ccs-*` tokens. A size, colour or radius the scale lacks gets a token in
  `tokens/semantic.css` (for example `--ccs-font-size-ui`, `--ccs-border-subtle`, `--ccs-radius-circle`), not a literal.
- **Wording**: titles and headings are sentence case ("Advanced search", "Help and support"), and a page's `<title>` starts with its h1.

## Filter rail and record page

- **Filter rail**: Blacklight's default facets (default components, markup, multi-select and the range limit plugin), unstyled
  by the app beyond the sidebar column, its type scale and the mobile drawer (`filter_drawer.css`, `facet_list.css`). The type
  follows the University's filtered listings: the "Search filters" heading is 24px / 600 Source Sans, a group's heading 18px / 600,
  filter names and values 18px, at every width.
- **Record page** (`components/record_split.css`, with shared parts in `record_page.css` and `digital_assets.css`): see "The record
  page layout" below.
  Field labels have no trailing colon (`blacklight.en.yml`).

## Search results layout

Designed in `search-results-bl.png` (the search results design); Europeana's open-source front end
informed the drawer and cards. Files: `components/results_layout.css`, `filter_drawer.css`,
`results_toolbar.css`, `search_banner.css`; `NexusCcs::FilterSidebarComponent`, `FilterToggleComponent`,
`ConstraintsComponent`, `ResultCardComponent`; `catalog/_sort_and_per_page.html.erb`.

- **Banner**: compact: "Search the collections" and a 2.5rem search bar (field selector left, cyan button).
  The result count moved to the toolbar; "Advanced search" is a link under the search bar in the banner, as on the static site.
- **Sidebar** (left, flush with the window edge, ruled on its right): the "Search filters (n)" heading, then Blacklight's own facet
  groups (the workbook's section titles as headings) of accordion filters. Creator role sits above Creator name (in the design,
  not in the workbook). Type: see "Filter rail" above.
- **Toolbar**: "N results for" with the search and each filter as a removable pill; sort and page size as
  select-style boxes; the view buttons flush right; a Filters button replaces the sidebar below 992px.
- **Results**: mosaic columns step with the width (written out as `repeat(N, 1fr)`, because the
  mosaic polyfill mis-sizes `auto-fill`): six columns at 2000px, 17rem tiles, 16px gutters. List is one
  column, two from 1880px, with the collection above the title and the image right on a dark box.
- **Pager**: small-caps Previous and Next around the page numbers, current page filled.
- **Below 992px** the sidebar is an off-canvas drawer from the left (22rem / 88vw max, 300ms, scrim
  `rgba(0,0,0,.7)`); focus moves in and is trapped, Escape and the scrim close it, scroll is locked, focus
  returns to the Filters button.

Not copied from Europeana on purpose: dropdown facets that apply at once, the page-number input, the
right-hand sidebar. Europeana's live site is bot-protected, so its values were not compared rendered.

## Header dropdowns

Browse collections and Help open the University mega menu's panel (`components/site_header.css`): full width under the header,
from 24px right of the logo block to the window edge, `#000b34`, 32px padding, 2px cyan top border; a 30px Fraunces title with a
30px arrow, a hairline, then 18px / 600 links with 20px arrows. The header is the positioning context, so both panels line up the
same. Below 1024px they are the phone drawer's lists.

## Colour mode

One design: light, whatever the browser or device is set to. Blacklight's colour mode script would otherwise set Bootstrap's dark
theme on pages whose own styles are light only (a half-dark page). `config.dark_mode_support = false` on `CatalogController` and
`StockCatalogController`, and `layouts/_light_theme` in all four layouts (`color-scheme` meta, `data-bs-theme` pinned to light).

## Not ported yet

Nothing from the static pages: help, about and the home hero are ported (the collection landing pages and the contact and search tips pages
were removed on both sites). See `docs/styling-inventory.md`.

## The record page layout

**The record page (branch `design/record-card`, 23 Nov 2026).** In `components/record.css`, after the University's design system
(designsystem.web.unimelb.edu.au) and the site's other pages, on white, capped at 1440px (`--layout-page`) with the site's gutters (16px,
32px from 768px). Header in two columns (5:7 from 1024px), the identity one block at the top level with the media panel's top edge, in three groups
32px apart (space groups them, no rules): the h1 as every page's (Fraunces regular, navy, 48px; 36px on a phone) with the date, the
maker and the record's collection with "See more from this collection" (the arrow link) under it; Associated names (a card-level heading; each name an in-content link, `ccs-text-link`, its role and dates under it), the
actions (`RecordActionsComponent`: Save as the site's outline button, Share, and More, a menu of Add to list, Cite this record and Copy
link, Compare under them); and the media
(`DigitalAssetsComponent`, Figma Record/IIIF viewer) on a light grey panel, sticky from 1024px. On a phone: the title, then the media, then
the names. Then sections, each after a full-width rule with its heading on the left (the site's section heading, `--ccs-heading-section-size`):
Object overview (the key facts, two columns, label a card-level heading above the value; names of things as the design system's tags,
`record-tags`), About this object (the description, Read more, CCS-413) and Record details and notes (`record-accordion`: the design
system's accordion as native `<details>`, title Source Sans 3 600 20px in link blue, the open panel on the pale grey surface). Last, You
may be interested in (`MoreFromCollectionsComponent`): the design system's tabs, at most five with short names (Similar, Same maker, Same
period, Same place, Same type; `tabs_controller.js`), the one on show on the primary cyan, each panel its full name as its heading and three
cards; Similar colours (Looks similar) is the Similar panel's second part. No class is named after a page, a design or another site.

**Showcase layout (branch `design/record-page-vam`, 20 Nov 2026, proposed).** After the museums' object pages (the V&A's was the
template), in the site's light theme, in `record_showcase.css`: the image whole and centred on a full-width grey band, its tools and
thumbnails under it; a white card (75rem) over the band's foot with the record: the collection, the title in Source Sans 3 bold with a
short navy rule under it, the object type and date on their own lines, the key rows (Creator, Place), the description fading out after
three lines above Read more (CCS-413), Object details (every data model field the record has, in the sheet's order, letter-spaced
capital labels beside values on dashed rules, names of things as outlined tags, long texts fading above Read more; open from 1024px,
closed on a phone), and About this record (centred heading, the text and content notice, Suggest a correction, the record URL with
Copy link, Print this page, and Download as CSV and IIIF manifest). Beside the record from 1024px, and between its header and Object
details on a phone, the actions and Use and access. Then You may also like (`similar/collage`, `?view=collage`: up to twelve similar
records' pictures laid like prints on a table, each a little turned, six at a time, with Shuffle; `shuffle_controller.js`) and More
from the collections. To keep the load low (20 Nov 2026, after Dean's wireframe): no collection link above the title (it is a row and
in the breadcrumb); Object details shows its first six rows and "Show N more details" continues the list in place, in the sheet's
order (era and region are left out: they repeat the date and the place); Use and access is a summary (view and download, the note,
the licence, the request link) with the rights items, terms and contact card under "Rights, credit and contact"; More from the
collections shows two rows and the others under "More ways to explore" (their frames load only once it is opened), and a row that
comes back empty is left out. The split layout below is the version on PR #87.

The approved split layout (Figma "Record page · Approved design (Version 4)", frames 28:2639 desktop and 29:2940 mobile, approved
19 Nov 2026), in `record_split.css`. From 1024px the media is on the left and the record's own column (33rem) on the right; the media
column is the page's one sticky element: it stays in view while the column beside it scrolls when it fits the window (`is-sticky`, set
by `media_viewer_controller.js`; a column made taller by video, audio or a notice scrolls with the page, so its tools can always be
reached), and sits under the sticky search strip when that has slid in (no transition, so a tool never slides from under a pointer). Below 1024px it is one column, media first, and nothing is sticky. Then three full-width bands.

- **Media** (`DigitalAssetsComponent`): the image whole, at its own shape, on the page's white (no dark band; dark only in full
  screen), sized so the whole column fits the window. Under it a controls row: the licence chip (Creative Commons mark) and the access
  chip on the left; round 44px tools on the right (Zoom in and Zoom out drive the OpenSeadragon viewer, Full screen, and Download only
  for an open image). With several images, a grey strip of every thumbnail (64px, 48px on a phone; the one on show has a 3px border
  and `aria-current`) with round previous and next. A view-only record has no download link in its markup; a request-only or
  not-yet-chosen sensitive record has no asset path in it, and its notice sits where the media would.
- **The record's column** (`RecordDocumentComponent`): "Result 3 of 120" with round previous and next (`ResultStepperComponent`,
  Blacklight's search context; first in the column at every width, so the reading order and the tab order agree), the collection (a link), the h1 in Fraunces, maker, date and
  medium; one row of actions (`RecordActionsComponent`: Save, Add to list, Share and embed, Cite, with Compare under it); **Use and access**
  (can the visitor view and download the image, the view-only or on-request note, the rights items of CCS-27 in its order, the request
  link and the contact card; the licence chip under the image links to it); the notices; the description, its first paragraph as the
  lead, collapsed with Show more / Show less (CCS-413: the lead clamped to three lines, the paragraphs after it hidden;
  `truncate_controller.js`); **Object details** (CCS-400: the data model sheet's fields, labels, order and display rules) as Key facts,
  then the full record in four groups that keep the sheet's sequence (The object, Physical description, Subject and classification,
  Collection and identifiers), open from 1024px and closed on a phone (`record_full_controller.js`); Key facts show only while the full
  record is closed. Rows are label above value (`RecordFactRowsComponent`), names of things as outlined terms that open their search or
  browse page, Source URL as View full record, the UoM ID last with Copy ID and Copy permalink (CCS-22); then two folding sections (How
  to cite this record, Acquisition and history), closed in the markup. The round i tool under the image opens the media information
  over it (CCS-422), and Download shows the caption and licence first (CCS-67).
- **Bands**: Related objects (`SimilarRecordsComponent`, three result cards in a lazy frame); More from the collections
  (`MoreFromCollectionsComponent`, on the grey surface: one labelled row per way the record matches, all in view, each an h3 and a lazy
  frame of three cards and See all, scrolling sideways on a phone); About this record (`RecordAboutComponent`: three
  rows, heading beside text). A lazy frame whose answer fails stays empty (`lazy_frame_controller.js`).
- Headings: h1 the title; h2 Use and access, Object details, the folding sections, Related objects, More from the collections, About
  this record; h3 Key facts, Full record, the rows of More from the collections, the About rows and the cards; h4 the full record's
  groups. Wording marked placeholder is in `config/locales/record_page.en.yml`.
