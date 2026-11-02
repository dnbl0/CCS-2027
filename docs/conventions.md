# Conventions shared by both codebases

## Names

- **Collections** have one slug each, used in URLs on both sites: `medical-history-museum`,
  `henry-forman-atkinson-dental-museum`, `harry-brookes-allen-museum`, `university-art-collection`, `grainger-museum`.
  There are no landing pages: a collection is the results page filtered by it (Rails `/catalog?f[collection_ssim][]=<name>`,
  static `/search/search-results.html?collection=<name>`). Rails keeps the list in `config/pages.yml` (menu label, Solr
  facet value `collection_ssim`, slug) read by `NexusCcs::SiteNavigation`; the old `/collections/<slug>` addresses redirect
  to the filtered results.
- **Pages** are named the same on both sites: home, collections (browse), a collection, help (one page with sections `faq`,
  `indigenous`, `copyright`, `access`), about. Contact, Indigenous data and Search tips are not pages of their own: Contact is the
  Help "Contact Us" section, and their old addresses redirect. Search results are `/search/search-results`
  (static) and `/catalog` (Rails).
- **CSS classes** follow BEM (`block__element--modifier`). The static pages scope a page's rules with a `page-<name>` class
  on `<body>`; the Rails pages use the same classes (they are generated from the static styles).
- **Design tokens** are the static site's `public/styles/tokens/tokens.css` (three tiers: primitives, semantic, component).
  The Rails app's own results styles use its `--ccs-*` tokens; the content pages use the static ones.
- **Collections are listed alphabetically** by name wherever they are all shown (header dropdown, Browse collections
  cards, contact groups): Grainger, Harry Brookes Allen, Henry Forman Atkinson, Medical History, University Art.
- **Header dropdowns** are the University's mega menu panel (designsystem.web.unimelb.edu.au/components/mega-menu, measured at
  1440px): full width under the header from just right of the logo, `#000b34` with 32px padding and a 2px cyan top border, a 30px
  serif title, a hairline, then one column of 18px / 600 links (`.ccs-nav__panel` static, `.site-nav__panel` Rails).
- **One colour design.** The site is light only, whatever the browser or device is set to (light, dark or auto): Blacklight's
  `dark_mode_support` is off, and `layouts/_light_theme` sets `color-scheme: light` and pins `data-bs-theme="light"`.

## Where a change is made

The words used for the product are in [CONTEXT.md](../CONTEXT.md); decisions that should not be undone by accident are in
[docs/adr](adr/).

| Change | Edit | Then |
|---|---|---|
| Styles or images shared by the pages | `public/styles`, `public/images` | `npm run sync:rails` (no longer enforced; see `docs/decoupling-from-2026.md`) |
| Header, search overlay, footer, Browse collections cards (static) | `src/partials/` | `npm run sync:partials` |
| Header and Browse collections cards (Rails) | `NexusCcs::HeaderComponent`, `app/views/pages/_browse_collections.html.erb` | the Rails app owns it (the static partials are a 2026 prototype) |
| Page copy | the static page and the Rails view / `config/pages.yml` | none |
| Rails results, record, filters | `ead-ccs-test/app` | `bin/rails test`, `bin/rails test:system` |

## Accessibility checklist (both sites)

Automated: axe-core (WCAG 2.1 A and AA) runs on the static pages (`tests/accessibility.test.js`) and the Rails pages
(`test/system/accessibility_test.rb`). Check by hand when a page changes:

- Keyboard: every control reachable and operable, visible focus, no keyboard trap (dialogs trap focus and close on Esc).
- One `h1` per page and headings in order; landmarks labelled (header, nav, main, footer).
- Text and controls meet contrast (4.5:1 text, 3:1 large text and controls); do not rely on colour alone.
- Images have `alt` text (empty for decoration); icons that are controls have a name.
- Reflow at 320px without horizontal scrolling; targets at least 44px on touch.
- Reduced motion respected (`prefers-reduced-motion`).
- Links that open a new tab say so to screen readers.
