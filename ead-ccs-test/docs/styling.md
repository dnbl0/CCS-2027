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
- **Record page** (`components/record_page.css`, `digital_assets.css`, `object_cards.css`): see "The record page layout" below.
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

After Apple's product pages, with the cues of a museum image viewer (the British Museum's) and the quality of the museum record
pages (V&A, Art Institute of Chicago, the Met, Europeana). Patterns only; nothing of those sites is copied.

- **Sub-navigation** (`RecordSubnavComponent`, from 1200px): the record's title and anchors (Overview, Object details, Copyright and
  use, About this record, More like this) under the site header. It is the one sticky element; `html:has(.record-subnav)` sets a scroll
  padding, so anchors and focused controls are never hidden under it (WCAG 2.4.11). It is not drawn below 1200px.
- **Two columns from 1200px** (58 / 42, 1200px content, 4rem gap; one column below, in the same order). Left, the viewer
  (`DigitalAssetsComponent`): the image whole on a soft stage, at its own shape and at most min(78vh, 760px) tall (the width and
  height attributes reserve it, so nothing moves), never a dark box; one band of pill buttons along the stage's bottom (Zoom and pan at the left, Media
  information and Full screen at the right, icons only on a phone; the zoom buttons appear top right while zoom is on; mouse-wheel zoom
  stays off), positioned against the stage so they line up and never cover the picture; a strip of every image under it
  (the current one outlined, scrolling sideways, 44px targets; the strip is the gallery, there is no second row of tiles); and three
  short lines under that, after Apple's: what the visitor may do, the licence, what there is to see. Dark only in full screen and
  in the zoom viewer.
- **Right, the record** (`RecordHeaderComponent`, `RecordActionsComponent`): an accent kicker (object type, collection), a very
  large Fraunces title, the creator link and date, one quiet line of place or material, the description with Show more, then the
  **access card** (`record_actions.css`): a line saying what the visitor can do, ONE full-width primary button where there is
  something to do (Download image when open; Request access when withheld; none when view-only, which gets its plain reason and a
  bordered link to ask), then Save as one full-width bar and Add to list, Compare, Cite this record and Share and embed as equal
  tiles, an icon over a label (one grid; the same on a phone), and the Collection ID with Copy.
- **No media**: no stage. `NoImageComponent` is a slim tinted band with the collection's monogram and one plain sentence
  (placeholder wording), and the record is one centred column.
- **Specifications**, after Apple's Tech Specs: a centred 960px column of label and value rows (a quiet sentence-case label, a hairline between rows,
  whitespace and not rules between sections). Object details (the workbook fields except the description and the rights fields; terms
  that link are plain underlined links, never boxed),
  Copyright and use, About this record (persistent link with Copy link, contact, correction link). They are `<details>`
  (`record_sections_controller.js`): accordions with Object details open below 768px, plain open sections from 768px.
- **More like this** (`MoreLikeThisComponent`): a soft band, one h2, up to three h3 sub-sections (Related objects, Similar records in
  a lazy frame, Recently viewed), up to four `RecordCardComponent` tiles each, no tabs. Every tile has the same 4:3 face: the image
  shown whole, or, for a record with no viewable thumbnail (or one whose file fails to load, `image_fallback_controller.js`), its object
  type on a tint; then a two-line title (the link of the whole tile) and a two-line creator and date. Four across from 1024px; below
  that a row that scrolls sideways and snaps, the next tile peeking.
- Headings: h1 the title; h2 Object details, Copyright and use, About this record, More like this; h3 the sub-sections. The viewer
  has no heading before the h1. Wording marked placeholder is in `config/locales/record_page.en.yml`.
- Not built from the brief, and why: the navigator mini-map (OpenSeadragon's own navigator is not styled to match; zoom and pan
  are kept as they were) and thumbnail arrows (the strip scrolls; every thumbnail is focusable); the separate tile strip is the same
  strip.

## The viewer layout (`?layout=viewer`)

An opt-in variant of the record page, built after the user's Claude Design mockup, on the same address (`catalog#show`; no new route, page
type or sitemap entry). Off unless the address has `?layout=viewer`; any other value is the plain page. The canonical link stays the
plain address (`CanonicalUrl` drops the parameter) and `RobotsPolicy` tells search engines to keep the variant out (`noindex, follow`).
It is meant for trying the layout on one record; if it wins, the default is flipped.

- **Components**: `RecordViewerComponent` (a `RecordDocumentComponent` with its own markup: the same fields, rights, contact and access
  rules; Object details, Collection and provenance, Rights and access and About this record are plain `<details>` accordions at every
  width, Object details open) and `ViewerMediaComponent` (a `DigitalAssetsComponent` with its own markup, so AccessPolicy and
  Sensitivity are the same code). `show.html.erb` picks the component; `RecordAboutComponent(viewer: true)` and
  `MoreLikeThisComponent(show_related: false)` adapt two shared parts. Styles: `components/record_viewer.css`; the page surface is the
  token `--ccs-surface-paper`.
- **Left, the viewer**: the picture whole (the sized figure, so nothing shifts), a counter badge ("1 of 10") top right, ONE grouped navy
  pill of four icon buttons at the bottom right (zoom in, zoom out, reset, full screen; each has an accessible name and a tooltip, 44px),
  a strip of thumbnails (the current one outlined, a slim scrollbar), and one quiet line: the keys the viewer takes ("+ and - to zoom,
  0 to reset"; there is no mouse-wheel zoom, it would take the page's scroll away), "Media information" and, for an open record only,
  "Download image". The sensitivity choice and the withheld notice stay inside the picture area, above the controls.
- **Viewer behaviour** (`deep_zoom_controller.js`, `deep_zoom_viewer.js`; the pill is `DeepZoomComponent(pill: true)`), after a museum
  viewer: one OpenSeadragon viewer for the whole record, switched to the chosen thumbnail; a press on a zoom button starts it; zoom in
  and zoom out are disabled where the view cannot go further that way; the canvas has the role "application", the name of the current
  image and a visually hidden long description (the record's description); a small navigator map shows while the viewer is on; on a
  screen 500px high or less (not full screen) it stops capturing touches and goes home so a phone held sideways can scroll past it
  (checked on resize, after 300ms); if an image cannot open, a plain sentence says so (placeholder wording); the viewer is hidden when
  printing. Not built: previous and next buttons (the strip does it) and a focus trap, because nothing here is an overlay.
- **Right, the record**: small caps kicker, a very large title, the byline, Save and a primary navy button ("Contact us" for the
  collection's team; "Request access" for a withheld record), one quiet line on what the visitor may do with the picture, then Add to
  list, Compare, Cite and Share as quiet text, the accordions, and the persistent link and Collection ID in a bordered card.
- **Below**: a white band across the page, ruled off, with Related objects as three large cards (4:3 pictures) and "View all in this
  collection"; More like this (Similar, Recently viewed) follows.
- The sensitivity choice and Compare redirect to the plain record address, so a visitor who makes one leaves the variant.
