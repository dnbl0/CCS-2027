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

One header block, not a title band: `RecordHeaderComponent` has a kicker (object type and collection, plain text, not chips), the
page's one h1, the creator (a browse link) and date, and the Collection ID with Copy. Under it, from 1200px, two columns (7/5):
the media (or one plain sentence when the record has no digital asset, `NoImageComponent`) with the sections under it, and a
plain column that scrolls with the page (nothing on the page is sticky, so focus is never covered) holding the actions
(`RecordActionsComponent`: the access notice of a view-only record, Save, Add to list, Compare, Cite, Share and embed) and the Key
facts (`KeyFactsComponent`, a `dl`). Below 1200px it is one column in the same order; the actions strip wraps and its targets are 40px.
Below 768px Compare, Cite and Share sit in a "More actions" disclosure (a `details` closed in the markup, so nothing shifts); Save and
Add to list stay visible. From 768px the disclosure is plain: its summary is hidden and its content shows (`::details-content`).
Motion is guarded by `prefers-reduced-motion: no-preference` in the result card, browse hub and results toolbar styles.

- **Media** (`DigitalAssetsComponent`, `digital_assets.css`): the image sits on the page surface, whole, at its own shape (at most
  70vh high), on a flat tint that holds its room from the `width` and `height` attributes (no minimum height, no dark band). Dark
  only in full screen and in the zoom viewer. One slim toolbar directly under the image: the access chip (Open, View only,
  Available on request) and the licence on the left; "Media information" and "Full screen" (icon and text label) and, for an open
  record only, "Download image" on the right. A view-only record has no download link in its markup; a request-only or
  not-yet-chosen sensitive record has no asset path in it, and its notice sits where the media would, the same width.
- **Sections** (`record_sections_controller.js`): Object details (the workbook fields not shown above), Copyright and use (licence,
  copyright note, credit line, a DAM caption only when there is one, responsible collection, terms link) and About this record
  (persistent link with Copy link, who to contact with the record ID, and a correction link to the same contact) are `<details>`.
  From 768px they are open and plain; below it they are accordions with 44px summaries, Object details open.
- **More like this** (`MoreLikeThisComponent`): one h2 and up to three h3 sub-sections (Related objects, Similar records in its lazy
  frame, Recently viewed), up to four `RecordCardComponent`s each, no tabs. A record with no image the visitor may see is a text
  card (kicker, title, creator and date), never a grey box.
- Headings: h1 the title; h2 Key facts, Object details, Copyright and use, About this record, More like this; h3 the sub-sections.
  Wording marked placeholder is in `config/locales/record_page.en.yml`.
