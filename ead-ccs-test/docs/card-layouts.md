# Card layouts

Added 2026-11-17. A section of cards need not be one grid: `NexusCcs::CardLayoutComponent` lays the same cards out in one of five shapes,
so a page of sections reads as a sequence of different moments (the pattern Google Arts & Culture uses, described in our own words; nothing
is copied from it). The cards are the site's result cards (`NexusCcs::ExploreCardComponent`). The CSS is `components/card_layouts.css`.

| Layout | What it is | Used by |
|---|---|---|
| `bento` | a feature card two cells wide and tall beside smaller ones; the last card two cells wide | Browse: Object types |
| `rail` | a row that scrolls sideways, the next card peeking, with round previous and next buttons (`card_rail_controller.js`) | Browse: Places |
| `strip` | from 900px the card pointed at or focused widens (the first one at rest); a two-column grid below | Browse: Periods |
| `grid` | an even grid of square pictures | Browse: Makers |
| `wall` | an even grid with a brand panel after the first card that opens the full A to Z list | Browse: Subjects |

`Browse::Cards::LAYOUTS` says which layout each Browse section uses.

## Rules every layout follows

- **The picture is whole**, on a mat (`object-fit: contain`), never cropped; no layout needs the picture's shape or size, so the DAM's pictures
  (whose size is not known) work.
- **No text over a picture**: the name and description are on the card's own white caption, so contrast does not depend on the image.
- **A card with no picture** is its name on one of the Explore tints, as large as the cell.
- **The markup is the same in every layout**: a list of articles, each with one heading link. The wall's panel sits after the first card in
  the source, so the reading order follows what is seen.
- **Motion is the visitor's**: the strip widens on hover or focus and the rail scrolls on a button press; with `prefers-reduced-motion` the
  strip's width change and the rail's scroll are instant. Nothing moves by itself.
- **The rail's row is focusable** (`tabindex="0"`, labelled) so a keyboard user can scroll it, and its buttons stay hidden without
  JavaScript and when there is nothing more to scroll to.
- **A narrow cell leaves out the description** (a container query), and the description is two lines at most.
- Tests: `test/components/nexus_ccs/card_layout_component_test.rb` and `test/system/browse_sections_test.rb` (axe at desktop and phone width,
  the bento's size, the rail's buttons, the strip's widening, no sideways scroll).

## Not done (yet)

- The fan of overlapping cards with a larger centre card, and a picture wall with no captions, were left out: both depend on motion or
  on text over pictures.
- The home page's sections still use the mosaic (the next step).
