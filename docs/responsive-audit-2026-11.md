# Responsive design audit (CCS-63, BR-16.07), November 2026

CCS-63 asks for a UI that is responsive "to accommodate laptops, tablets and mobile devices" ("More details??": the story has no further
criteria or comments). The audit uses WCAG 2.2 1.4.10 Reflow, 1.4.4 Resize text, 1.4.12 Text spacing and 2.5.8 Target size as the
measurable criteria.

## Method

- Headless Chrome (Cuprite) against a local server, at 320, 360, 390, 768, 1024 and 1280 px wide.
- Per page and width: `scrollWidth <= innerWidth`, elements reaching past the right edge, visible links, buttons and fields under
  24 px in either direction (links inside a sentence are exempt, as in 2.5.8), tables outside a scrolling box.
- Text at 200%: `html { font-size: 200% }` at 320 and 390 px. Text spacing: line height 1.5, letter spacing 0.12em, word spacing 0.16em,
  paragraph spacing 2em, injected as a stylesheet.
- Keyboard: Tab through the results, record, advanced search, help, about and access form at 320 px with the sticky search bar showing;
  no focused control sat under the bar.
- Pages and states: home, results (list, mosaic, gallery), the filter drawer, the facet "more" modal, a record with images, `/stock/:id`,
  `/branded-stock/:id`, advanced search, help, about, search history, saved searches, saved records, lists (index, a list), the access
  request form (empty, with errors), the phone menu, the desktop header dropdown and the search overlay.
- Not covered: real devices and touch (the checks use a desktop engine), a screen magnifier, browser page zoom beyond the 320 px window.

## What was already good

No page scrolled sideways at any width, before or after the changes (the 390 px record page was fixed earlier, see
`test/system/record_media_reflow_test.rb`). The tables (search history, saved searches) turn into cards or fit; no table sat outside a
scrolling box. Line length is limited by the pages' own `max-width`s. The sticky search bar never covered a focused control
(`html { scroll-padding-top }`, components/sticky_search.css).

## Findings

Status: Fixed (CSS in `components/responsive.css`), Out of scope (explained), Open.

| Page | Width | Issue | Fix | Status |
| --- | --- | --- | --- | --- |
| Record `/catalog/:id` | 320, 360, 390 | The title sat in a narrow column beside Save and Add to list and broke a word ("Ethelred / a") | Under 600 px the summary is one column; the buttons sit under the title | Fixed |
| Help, About, Saved records, Lists, Access form error summary, record details and copyright, empty results | all | Links on a line of their own are 22 px tall (line box of 16 px text), under 24 px | `padding-block: 0.25rem` on text links in the content (not buttons, not image links) | Fixed |
| Record | all | "View full record" button 21 px, persistent link field 23 px, Copy button 24 px | `min-height: 1.5rem` | Fixed |
| Phone menu (under 1024 px) | 320 to 768 | The UniMelb audience links (Study, Students, ...) are 20 px tall | 44 px rows, the gap moved into the row | Fixed |
| Facet "more" modal | all | The value links are 22 px tall | `padding-block` on `a.facet-select` in the modal | Fixed |
| Results | 320, 390 at 200% text | The view buttons (48 px square, in rem) widened the toolbar past the window | 44 px square buttons under 600 px; the toolbar's right-hand group wraps | Fixed |
| Record media toolbar | 320 at 200% text | The licence chip and the two buttons overflowed the window | The toolbar row wraps; the buttons are 40 px square in px, so they do not grow with the text | Fixed |
| Footer (every page) | 320 at 200% text | The Acknowledgement heading and the flags row were wider than the window | Grid children may shrink, flags wrap, headings break long words | Fixed |
| Home | 320 at 200% text, and with 1.4.12 text spacing | The search button went up to 76 px past the window | The search group wraps | Fixed |
| Breadcrumb strip | 320 at 200% text | The "saved records" link ran past the window | The strip wraps; the link may take the full row | Fixed |
| Record media toolbar | 320 | After the fix the licence chip and the buttons sit on two rows at 320 px | Accepted: nothing is lost, and it is the price of reflow at large text | Fixed |
| `/stock/:id` | all | Links in its lists are 18 px tall | None: this page is Blacklight's stock layout (`stock_blacklight.css`), kept unstyled for comparison; `/branded-stock/:id` has the fix | Out of scope |
| Results | 320 | "Sort by relev..." in the sort menu is cut with an ellipsis | None: the full name is in the menu and the control's name; no loss of function | Out of scope |
| Everything | all | Touch, pinch zoom, orientation change and real phone browsers | Not testable here | Open (test on devices) |

## Template changes

None. All fixes are CSS in `app/assets/stylesheets/components/responsive.css`, imported last in `application.css`.

## Tests

`test/system/responsive_test.rb`: the nine key pages at 320 and 390 px (no sideways scroll, no button or link under 24 px in `<main>`), the
phone menu at 320 px (44 px links), a results page at 320 px with text at 200%, and axe at 320 px on a results page, a record and the access
form. Without `responsive.css` nine of these fail.
