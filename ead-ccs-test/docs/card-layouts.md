# Card layouts

Added 2026-11-17. A section of cards need not be one grid: `NexusCcs::CardLayoutComponent` lays the same cards out in one of five shapes,
so a page of sections reads as a sequence of different moments (the pattern Google Arts & Culture uses, described in our own words; nothing
is copied from it). The cards are the site's result cards (`NexusCcs::ExploreCardComponent`). The CSS is `components/card_layout.css` (the card itself: `components/explore_card.css`). `NexusCcs::CardSectionComponent` is the section around
them (heading, See all link, intro), and `CardDescription` works out the line under a card from the records it opens.

| Layout | What it is | Used by |
|---|---|---|
| `bento` | a feature card two cells wide and tall beside smaller ones; the last card two cells wide | Browse: Object types; Home: Record types |
| `rail` | a row that scrolls sideways, the next card peeking, with round previous and next buttons (`card_rail_controller.js`) | Browse: Places; Home: Places (eight, `ExploreEntryPoints::PLACES_SHOWN`) |
| `strip` | from 900px the card pointed at or focused widens (the first one at rest); a two-column grid below | Browse: Periods; Home: Time |
| `grid` | an even grid of square pictures | Browse: Makers |
| `wall` | an even grid with a brand panel after the first card that opens the full A to Z list | Browse: Subjects |

`Browse::Cards::LAYOUT_BY_HUB` says which layout each Browse section uses. `bin/rails browse:warm_cards` builds the Browse cards now (otherwise the first
visit after a day does, and a cache entry that is being rebuilt is still served to other visitors for 30 seconds).

## Rules every layout follows

- **The picture fills its tile** (`object-fit: cover`, centred), since 2026-11-18 (Dean asked for picture-led sections like Google Arts &
  Culture's, in our own words and tokens). No layout needs the picture's size, so the DAM's pictures work. The record page always shows the
  whole picture. Styles: `components/card_tiles.css`, loaded last in `application.css`.
- **The name sits on a navy scrim** at the foot of the tile: at least 85% navy wherever there is text, so white text keeps about 12:1 or more
  contrast whatever the picture. In forced-colours mode the caption takes the system colours.
- **Sections are centred** (heading and intro) with **See all** under the cards (`CardSectionComponent`). The home Time section is the
  page's one navy band. The home collections are a mosaic of picture tiles led by a large one (`ExploreComponent`, over `film_polish.css`'s masonry).
- **A card with no picture** is its name on one of the Explore tints, as large as the cell.
- **The markup is the same in every layout**: a list of articles, each with one heading link. The wall's panel sits after the first card in
  the source, so the reading order follows what is seen.
- **Motion is the visitor's**: the strip widens on hover or focus and the rail scrolls on a button press; with `prefers-reduced-motion` the
  strip's width change and the rail's scroll are instant. Nothing moves by itself.
- **The rail's row is focusable** (`tabindex="0"`, labelled) so a keyboard user can scroll it, and its buttons stay hidden without
  JavaScript and when there is nothing more to scroll to.
- **A narrow cell (under 10rem) leaves out the description** (a container query), and the description is two lines at most. Every card on the
  home page and the Browse page has one ("Includes prints. Held in the University Art Collection."), worked out from its records.
- **A title is never cut off**: the strip's narrow cards use a smaller title that wraps, and widen to the full size on hover or focus.
- **The rail keeps the keyboard focus**: a button that is about to be hidden (the end of the row) hands the focus to the row first.
- Tests: `test/components/nexus_ccs/card_layout_component_test.rb`, `card_section_component_test.rb`, `test/models/card_description_test.rb` and `test/system/browse_sections_test.rb` (axe at desktop and phone width,
  the bento's size, the rail's buttons, the strip's widening, no sideways scroll).

## Not done (yet)

- The fan of overlapping cards with a larger centre card was left out: it depends on motion.
- The home page's collection tiles keep their own design (monogram tiles).
