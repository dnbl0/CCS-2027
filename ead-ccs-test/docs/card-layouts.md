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

## The home page (redesign, 23 Nov 2026)

After the homepage redesign wireframe ("Collections Navigator Homepage Redesign") and Google Arts & Culture's mixed layouts (looked at
for ideas, described in our own words; nothing copied). **No picture on the home page is cropped** (Dean): where Google Arts & Culture
crops pictures to fixed cells, here the cell follows the picture.

| Section | Layout | Code |
|---|---|---|
| Explore the collections (every collection) | fluid mosaic, the University Art Collection leading | `MosaicComponent`, `HomeSections.collections` |
| Collections within the collections | fluid mosaic, the largest leading | `MosaicComponent`, `HomeSections.named` |
| Record types (every kind) | a shelf of collage cards: three of each kind's records side by side, each whole | `CollageCardComponent`, `HomeSections.kind_collages` |
| Places | a list beside a collage of four of the place's records (different records for each place where it can) | `PlacePreviewComponent`, `HomeSections.place_collages` |
| Time | justified rows (`CardLayoutComponent` `:justified`) on the navy band | `justified_controller.js` |
| On this day, More ways in | fluid mosaic (`CardLayoutComponent` `:mosaic`, and the ways partial) | `mosaic_controller.js` |

- **Fluid mosaic** (`mosaic_controller.js`, `components/home_sections.css` `.mosaic-flow`): a 12-column grid (8 on a tablet, 4 on a
  phone, one tile to a row) with 8px rows. Each tile's columns come from its picture's shape (`--a`, width over height; wider pictures
  more columns, the lead more again, a light rhythm so neighbours differ) and its rows from its height. Tiles are placed in order at the
  lowest place they fit, narrowing (to 70%) to fit a gap or widening to take a strip too narrow for another tile, so the reading order
  runs from the top left. Without JavaScript: an even grid of the same cards.
- **Justified rows** (`justified_controller.js`, `.justified`): each card's flex-grow and flex-basis are its picture's shape, so a full
  row's pictures share a height and the row fills the width; a last row under 60% full keeps the row height.
- A picture's shape comes from the server when its size is known (the Explore tiles, the site's own pictures via `ImageDimensions`)
  and is measured in the browser otherwise; it is held to 0.5–2.6. Unknown shapes are fitted (`object-fit: contain`), never cropped.
- The cards are the site's result card in a tile variant (`explore-card--tile`, `--lead`, `--collage`): picture above, name below on
  white, the title's link covering the card. No navy scrim on the home page (`card_tiles.css` keeps it on the Browse page).
- Collage pictures come from `Showcase` (licensed and not sensitive, cached six hours); the Indigenous Collections tile stays text only.
- Tests: `test/system/home_explore_test.rb` (axe, 44px targets, no sideways scroll, **no cropped picture**, the mosaic interlocks),
  `test/components/nexus_ccs/{explore,mosaic,card_layout}_component_test.rb`, `test/models/home_sections_test.rb`.

## The Browse templates (23 Nov 2026)

Every Browse page uses one of two templates, after Google Arts & Culture's Places pages (looked at for ideas; nothing copied). Pictures are
never cropped.

| Template | Pages | Code |
|---|---|---|
| **List** | Object types, Places, Periods, Makers, Subjects (`browse/hub`: All, the mosaic; A–Z or In order; live search; Places' regions); the Browse page; Browse by category and a category's values; Themes; Stories; the head of the timeline and the map | `browse/hub.html.erb`, `browse/_page_head.html.erb`, `MosaicComponent`, `CardLayoutComponent` `:mosaic`, `places_search_controller.js` |
| **Detail** | each place, maker, subject and period (`browse_entities/showcase`); each collection, named collection and theme (`collection_landings/_showcase`); each story (its head and record groups) | the picture strip (a justified row), the centred head, chips, the Discover or Highlights mosaic |

- A card opens the value's own page where it has one (a place, maker, subject, period, collection or named collection), otherwise its
  records in the search: `Browse::Cards::Card#path`, `ExploreCardComponent#path`, `LandingHelper#landing_path_for`.
- Counts on a wall are every record with the value (`Browse::Cards.with_totals`), so the wall, the list and the search agree.
- Checked with axe at desktop and phone width on every one of these pages (23 Nov 2026).
