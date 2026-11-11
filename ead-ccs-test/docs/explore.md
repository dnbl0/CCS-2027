# Home page: Explore the collections

The section under "Welcome to Collections Navigator" on the home page. Code: `NexusCcs::ExploreComponent`, `ExploreEntryPoints`
(`app/models/explore_entry_points.rb`), `config/explore_kinds.yml`, `components/explore.css`, `explore_disclosure_controller.js`, wording in
`config/locales/explore.en.yml`. Tests: `test/components/nexus_ccs/explore_component_test.rb`, `test/models/explore_entry_points*_test.rb`,
`test/integration/home_explore_test.rb`, `test/system/home_explore_test.rb` (axe at desktop and phone, layout shift).

It adds no route and no URL scheme. Every link is an existing `/catalog` facet URL (with the `any_assets` marker, so the default
"With a digital asset" filter stays off, docs/adr/0004) or an existing browse hub (`/browse/places`, `/browse/periods`, `/browse/object-types`).

## What it shows

| Group | Source | Shape |
|---|---|---|
| Browse by collection | `collection_ssim`, most records first. `[other]` and values under 100 records are hidden; at most 6 | A tile each: 16:10 face, the whole tile is one link, the title an `h3` inside the link, the exact count in the same link. 3 per row from 768px, 2 from 600px, a compact row (48px face beside the text) on a phone |
| Kinds of records | `kinds` in `config/explore_kinds.yml`: a label and the `classification_ssim` values it stands for | A plain list of arrow links in two columns, no counts, and "See all object types" |
| Place and time | The 5 most common `production_place_ssim` values (minus the repeated or enclosing ones in `places.skip`), and the periods in the same file | Two disclosures (`details`): closed on a phone, open from 768px (CSS shows the content at that width at once, the script sets `open`). Each ends with "See all places" / "See all periods" |

The layout follows the University's Listings component (16:10, the whole item is the link, `h3`) and its Library collections page (plain grouped
link lists). Decisions and research: the record-and-Explore plan and addendum of 2026-11-11 (sections B, D, E WP1).

### The curated kinds

`kinds` maps a label to classification values (the raw field mixes levels: "Art and design", "prints", "paintings", "Photography, Sound and Film"...).
The link opens the records with **any** of the values (`f_inclusive`, as the browse pages do); a kind with one value uses the plain filter.
The number is the real count of records with any value of the kind, from one `facet.query` each, so a record with two values counts once
(summing the facet counts would double-count). A value the index does not have is left out of the link; a kind with no value in the index
or no records is left out of the list. A value belongs to one kind only (a unit test checks it). To change the list, edit the YAML:
labels in sentence case, no code change. Check real values with Solr facets (`facet.field=classification_ssim`).

## The designed face and example images

Few records have a picture (about 137 of 49,000), so the **designed face is the default**, not a fallback: a tint and the first letters of the collection's first two words (UA, MH, GM) in Fraunces, drawn with CSS (no image file). The six tints are `--ccs-explore-tint-1..6` in `tokens/semantic.css`, mapped to palette
tokens; the text on them is navy (`--ccs-text-brand`), well above 4.5:1. The letter is decoration (`aria-hidden`); the `h3` names the link.

A tile shows a picture instead only when `ExploreEntryPoints` kept one for its collection, and the locks are unchanged:

- the record's asset is one anyone may download (`AccessPolicy` `:open`, through `Discovery.pickable?`),
- it is not sensitive (`Sensitivity`),
- its thumbnail is a file this server holds, so its width and height are known (`ImageDimensions`),
- the picture is shown whole (`object-fit: contain`, never cropped), lazy, sized by its attributes, with an empty `alt` (the title is the link text).

Nothing else about the record is kept, and no path of a withheld record. The component checks again that the path is a local one.

### Indigenous Collections: always text only

The Indigenous Collections tile never has a picture. `ExploreEntryPoints` does not look for one (`collections.text_only` in the YAML), and the
component refuses to draw one even if it is given. Reason: the choice of image for this collection is waiting for cultural review (the
University's Indigenous advisers); the label itself is the collection's own name. When the review has chosen an image, remove it from
`text_only` and decide how the image is chosen. Wording on the section is placeholder until the collections team approves it.

## Caching and Solr being down

One Solr request (three facet fields, one `facet.query` per kind and period) plus one request per collection for its example image, kept for a
day under `explore_entry_points/v2`, with the last good answer kept for a month. With Solr down and nothing kept there are no counts, the
overview is empty and the home page leaves the section out (CI has no Solr). Image lookups failing costs the images, not the numbers.

## Accessibility and performance

- Headings: `h2` for the section; each tile title, "Kinds of records" and "Place and time" are `h3`. The tile list is labelled "Browse by collection".
- Every link and summary is at least 44px tall; focus is a 3px ring (on the whole tile for tiles). No sideways scroll at 320 or 390px.
- On a phone, with the disclosures closed, the section is about 1.5 screens (a system test checks it stays under 1.6).
- The home page HTML stays under 64 kB (`PerformanceTest`, docs/performance.md); one more small controller is preloaded (57 allowed).
- No motion except a 4px arrow nudge on hover, off for reduced motion.
