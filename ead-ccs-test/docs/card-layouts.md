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
| Explore the collections | the University's simple listing (as museumsandcollections.unimelb.edu.au/collections): its 24 collections, four to a row, a 16:10 picture filling its frame, the title under it; the same titles and pictures | `SimpleListingComponent`, `HomeCollections` (`config/home_collections.yml`) |
| (within Explore the collections) University of Melbourne Art Collection | under its own heading, as on the University's page: the 12 collections within it in the same listing, each opening its named collection here (Hugh Ramsay: his maker page) | `SimpleListingComponent`, `HomeCollections.art_collection` |
| What do you want to explore? (four) | Google's picture-only stack: Explore by place, by time and by colour, and Stories; nearly square pictures, each name on a white label in the picture's visible corner; each takes a picture no section above uses | `StackComponent` (`captions: false`), `ExploreComponent#way_tiles` |
| Object types (five) | on a band of colour (`HomeSectionComponent` `tint:`, as Google's sections with a `--section-background-color`); a fanned stack of cards, after Google Arts & Culture's "SimpleStack": the centre card at full size, the others smaller (86%, 78%, 72%), further back and dimmer, pushed outward so a slice of each shows; pointing at a card or focusing it makes it the centre. Drawn by CSS (no layout shift); a sideways-scrolling row on a phone | `StackComponent`, `stack_controller.js`, `ExploreComponent#kind_tiles` |
| Look closer | after Google's "Guess the artwork from the pieces": a full-width band, in a pale tint of the picture's own colour (navy text at 7:1), of twenty square close-ups of one record's picture in columns running off both sides, the text panel in the middle linking to the record; the close-ups are the picture's busiest parts (read small from the DAM, cached a month); one record a day from `config/home_look_closer.yml` (no First Nations works cut into pieces) | `LookCloserComponent`, `HomeLookCloser`, `components/look_closer.css` |
| Places (five) | Google's plain stack: the same fan as Object types, each card opening the place's own page | `StackComponent`, `ExploreComponent#place_tiles` |
| Time | after the National Gallery of Art's "Now on view" (nga.gov/calendar?tab=exhibitions, 25 Nov 2026): a card for each period in time order, the next one cut off at the edge; a 4:3 picture filling its frame, the title in the heading face, its years in bold, its line; on hover the picture grows (1.25, 0.6s) and a brand-colour line grows under the title; under the row a rule, round previous and next buttons and "1 of 4"; arrow keys move it; no longer a navy band (it takes its turn in the alternation) | `CardCarouselComponent`, `carousel_controller.js`, `components/card_carousel.css`, `ExploreComponent#period_spans` |
| On this day | after Google's "Clusters", on a band of colour: four cards of different sizes in one block (two tall, two wide stacked; three: one large, two stacked), each picture filling its card, the title and maker and date white on a navy shade at its foot; on a phone one full width, two side by side, one full width; fewer than three pictures, the mosaic | `ClusterComponent`, `components/cluster.css` |
| Recently viewed | the same tiles: a record's picture, its title, its maker and date | `MosaicComponent`, `record_tile` |

Google's masonry of whole pictures (its partner pages' asset grid: four columns, each picture at its own shape, its title and maker under it) is the site's mosaic already (`MosaicComponent`, `mosaic_controller.js`), so it is not a layout of its own. The cluster and the carousel may be used by any section: each takes `HomeSections::Tile`s.

Every section is the same lane masonry, led by its first tile (two lanes wide where its picture is not tall); a short section places its
tallest tiles first after the lead (Time keeps its order) and lets its last pictures grow to end level. The line under a record type's,
place's or period's name says what its page holds (the kinds of record and the collections that hold most of them, `CardDescription`),
not its number of records. No picture is used twice among the record types, places and periods (`ExploreComponent#collage_tile`: the first of a value's pictures no
tile before it has used).

- **Fluid mosaic** (`mosaic_controller.js`, `components/home_sections.css` `.mosaic-flow`): a 12-column grid (8 on a tablet, 4 on a
  phone, one tile to a row) with 8px rows. Each tile's columns come from its picture's shape (`--a`, width over height; wider pictures
  more columns, the lead more again, a light rhythm so neighbours differ) and its rows from its height. Tiles are placed in order at the
  lowest place they fit, narrowing (to 70%) to fit a gap or widening to take a strip too narrow for another tile, so the reading order
  runs from the top left. Without JavaScript: an even grid of the same cards.
- **Justified rows** (`justified_controller.js`, `.justified`): each card's flex-grow and flex-basis are its picture's shape, so a full
  row's pictures share a height and the row fills the width; a last row under 60% full keeps the row height.
- A picture's shape comes from the server when its size is known (the Explore tiles, the site's own pictures via `ImageDimensions`)
  and is measured in the browser otherwise; it is held to 0.5–2.6. Unknown shapes are fitted (`object-fit: contain`), never cropped.
- The cards are the site's result card in a tile variant (`explore-card--tile`, `--lead`): picture above, name below on
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

## The mosaic's forms, and pictures for every value (23 Nov 2026)

One component (`NexusCcs::MosaicComponent`, `mosaic_controller.js`) lays out every picture section, in the form that suits how many
tiles it has. Every picture is whole; no form crops.

- **One row** (no more tiles than lanes): the pictures share one height and the cards are made one height.
- **Justified rows** (under three rows of lanes, no lead tile): the tiles, in order, are shared among rows of about the same total width,
  and each row is exactly as wide as the list, as a photo wall. No holes, and the order is kept (periods read 1000 to 2099). A card is
  never narrower than 11rem.
- **Lanes** (longer mosaics, or any with a lead): masonry, each tile in the shortest lane; `ordered:` puts each in the next lane in turn
  so a long sequence keeps its order.

The ways in on a place, maker, subject or period page, and a collection's or theme's object types, eras and named collections, are
picture tiles (`browse_entities/_facet_tiles`). Each value's picture comes from `Browse::FacetPictures`: the page's own records first,
then the value's records anywhere in the collections (one grouped request for all the values the page's records do not show; both kept
for a day). A value with no picture anywhere (for example a subject whose 4,067 records have no picture that may be shown) is not a tile:
it is listed after the mosaic under "With no picture to show", so every card in a mosaic has its picture and no value is lost.

## Browse on the home page's layouts (24 Nov 2026; one Browse since 25 Nov)

`/browse` (Browse by category merged in; `/browse/categories` redirects there, sections in `CategoriesHelper::BROWSE_SECTIONS`) is laid out as the home page is: the Browse pages' centred head, then a full-width section for each way of grouping,
its heading and "See all" as the home page's, the backgrounds taking turns (white, grey) and two on bands of colour. Each section's cards
are the values with the most records, in one of the home page's layouts (`CategoriesHelper::CATEGORY_LAYOUTS`):

| Section | Layout |
|---|---|
| Object types | fanned stack (five), on a band of colour |
| Classifications | cluster (four) |
| Materials | picture-only stack (four) |
| Regions | fanned stack (five) |
| Eras | story carousel (eight, in time order) |
| Collections | cluster (four), on a band of colour |
| Named collections | fanned stack (five) |

No picture is shown twice on the page; a value with no picture of its own (most object types) borrows one of its records' from anywhere
in the collections (`Browse::FacetPictures#prepare`, one grouped request a section, kept a day). Too few pictures for a layout, the
section is the mosaic. On each category's own page (`/browse/classifications`, `/browse/materials`, `/browse/collections`, `/browse/named-collections`), the first page by most records opens with the four with
the most records as a cluster ("Most records"), then the rest in the mosaic; A to Z and later pages are the mosaic alone.

## Pictures load gracefully, everywhere (24 Nov 2026)

After Google Arts & Culture: a picture is hidden on its frame's flat colour until it has fully loaded, then fades in over 300ms
(`page_loader.js` marks it `is-revealed`; `components/image_reveal.css` lists the frames: walls, clusters, carousels, stacks, the mosaic's
cards, close-ups, Explore by colour's cards). On the colour and time walls the frame's colour is the picture's own main colour (its
palette's first, `PictureWall::Record#tint`). Without scripts pictures show as they load; whatever happens they show after six seconds;
with reduced motion they appear without fading.

Explore by colour, before a colour is chosen, is a card for each colour (four of its pictures in a square on the colour, a bar of the
colour, its name and count); a chosen colour's wall has the colours before and after it beside its head and a bar of the colour under it.
