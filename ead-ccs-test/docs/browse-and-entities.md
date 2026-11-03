# Browse hubs and entity pages

## In plain language

The site now has a **Browse** section, in the spirit of Europeana's pages for people, places and topics and Google Arts &
Culture's "explore by". `/browse` offers four ways in: **creators**, **places**, **subjects** and **time**. Each has an A to Z
(or century and decade) list with a record count beside every name and a box to type part of a name (it works without
JavaScript). Every name, place, subject, century and decade has a page of its own: facts (record count, years, main
collections, object types), a grid of its records with images first, a "See all N records" button into the search, and links to
related people, places, subjects and periods. Nothing is stored: every list and page is worked out from the search index and kept
in a short-lived cache.

Wording on the new pages is placeholder wording until the collections team approves it.

## What the index holds (read-only survey of the 40,962-record shared core, 3 Nov 2026)

| Use | Solr field | Distinct values | Records with a value | Values with 5+ records | Values with 1 record |
| --- | --- | --- | --- | --- | --- |
| Creators | `creator_ssim` (plain name; `creator_display_ssim` is "Name (born - died) Role") | 7,821 | 31,594 | 884 | 5,180 |
| Places | `production_place_ssim` | 1,018 | 13,355 | 277 | 502 |
| Subjects | `subject_ssim` | 1,601 | 15,894 | 368 | 887 |
| Time | `date_start_isi` (integer year; negative is BCE) | n/a | 28,264 (1,403 BCE; min -250000, max 2025) | n/a | n/a |
| Object types (not built) | `object_type_ssim` | 1,085 | 39,503 | 441 | 363 |
| Collections | `collection_ssim` (6), `named_collection_ssim` (344) | | | | |

Also: `creator_role_ssim` (117 values: creator, artist, publisher, composer...), `creator_birth_isim` / `creator_death_isim`,
`associated_entity_ssim` (1,571, mostly people again), `cultural_group_ssim` (2 records only).

Quirks found, and what the browse code does about each:

- **Noise.** "Unknown" (1,400 records), "Unknown (posters)" (1,309), "Anonymous" (14), places "Unknown" (36). They get no page and
  no list entry (`Browse::NOISE`); the records stay in search. Things like "396, manufacturer" or "3M (estab. 0190), manufacturer" are
  real but poor creator values from EMu; left as they are and reported to the data team (see open questions).
- **Spelling variants.** 9 creator, 20 place and 56 subject groups differ only in case, brackets or marks ("Portraits" and
  "portraits"; "Europe" and "Europe (?)"; "[London]"; "Hirschfeld-Mack" and "Hirschfeld Mack"). `Browse::Slug.fold` folds them to one
  entity, named by its commonest spelling; the page and the search cover every spelling.
- **Hierarchies in one string.** Subjects such as "MUSIC--Published" (473 with `--`) and places such as "Melbourne, Victoria, Australia"
  are single values; they are not split into a tree (a possible next step).
- **Images are rare.** Only 137 records have a digital asset (134 with a thumbnail), so most entity grids are cards without
  media. Records with images are sorted first (`has_digital_asset_bsi desc`).
- **Dates.** 12,698 records have no start year. Years run from -250000; 15 are earlier than 5000 BCE and share one period.
- Multi-valued fields: a record counts once for every value it has (a record with two creators is on both pages).

### Indigenous names and cultural protocols

The code has no rule that changes how a name is spelled or shown (the CCS-421 rules are not in this repository; the only coded
pieces are `AccessPolicy` (ICIP Rights, Community Restricted, "restricted"), `Sensitivity` ("sensitive" restriction notes) and
the cultural-protocols notice on record pages). The browse pages therefore: show names exactly as catalogued; show a "Cultural
care" notice (placeholder wording, links to Help) when any record of the page is under those protocols (one facet query) or the
name mentions Aboriginal, Indigenous, Torres Strait Islander or First Nations; and leave withheld (`AccessPolicy :request`) and
sensitive records out of the grid altogether, with a note that some are not previewed. Their count is still in the totals and the
search.

## URLs

| Page | URL |
| --- | --- |
| Overview | `/browse` |
| A to Z hub | `/browse/creators`, `/browse/places`, `/browse/subjects`; `?letter=G` (A-Z or `0-9`), `?filter=words`, `?page=2` |
| Entity | `/browse/creators/grainger-percy-aldridge-4cdea47c6e` |
| Time hub | `/browse/time` |
| Period | `/browse/time/1900-1999` (century), `/browse/time/1920-1929` (decade), `/browse/time/bce-500-401`, `/browse/time/before-5000-bce` |

**Slug scheme.** `readable-words-` plus ten hex characters of SHA-256 of `kind:folded-value`. Deterministic (a link can be built from
a record alone, no lookup), collision-safe (the hash decides; the words are cosmetic; a stale or edited word part gets a 301 to the
right address; an unknown hash is a 404) and safe (letters, digits and hyphens only; the value found by it comes from the index, is
escaped as a Solr phrase, and no visitor text is ever put in a Solr query: the hub filter is applied in Ruby). Period addresses are
validated exactly (a span must be a whole century or decade) so there is nothing to enumerate.

## How it is built

- `Browse::Index` reads one facet (`facet.limit=-1`, `facet.mincount=1`) per kind and caches the grouped list for 6 hours. The
  whole list is read at once instead of letter by letter with `facet.prefix` / `offset`: the largest field is 7,800 values, the entity
  address lookup needs the whole list anyway, and the A-Z bar, the filter box and paging are then answered from memory. If a field
  grows to hundreds of thousands of values, `Index.load` is the single place to switch to prefix and offset requests.
- `Browse::Periods.counts` makes two range-facet requests (centuries from 5000 BCE; decades from 1700), cached 6 hours.
- `Browse::Profile` makes **one** request for an entity or period page: 24 records, facets for collection, object type, creator, place
  and subject, stats on `date_start_isi`, century (or decade) ranges, and a facet query counting records under cultural protocols.
- Record pages link their place, subject and creator values to the browse page without any Solr request (the slug is computed from
  the value); the link leads to a page that always exists for a non-noise value.
- No external service is called at runtime. Enrichment hook (not built, off by default): a later `Browse::Enrichment` could add a
  Wikidata `sameAs` to `Browse::Meta#about`; it should be a stored, reviewed mapping, never a live lookup.

## Search engines

- Hubs and pages with **5 or more records** (`Browse::MIN_INDEXED_RECORDS`) are indexable with a canonical address (the letter and
  page parameters are kept; the filter box is dropped), a title, a description and JSON-LD (`CollectionPage` with `about` as `Person`
  only when records show life dates, otherwise `Thing`; `Place`; `DefinedTerm`; a breadcrumb list). No image and no record title
  are ever put in the JSON-LD.
- Thinner pages, filtered hub lists and page 2 on are `noindex, follow`. They work as normal.
- **Sitemap policy:** the five hubs, every entity with 5+ records (about 1,500 today) and every century or decade with 5+ records. That is a
  small fraction of one 10,000-URL sitemap page. The lists come from the cache, so building the sitemap adds no Solr walk.

## Budgets

Warm cache: a hub or the overview makes 0 Solr requests; an entity or period page makes 1. Cold: one request for each list it
needs (at most 5 on the first visit), then cached for 6 hours. No new scripts or importmap pins; the stylesheet is one more file
inside `application.css`. The home page grew by about 1 kB (budget 56 kB).

## Open questions

1. Should the hierarchies (subjects with `--`, places "Town, State, Country") become a tree?
2. Are the CCS-421 Indigenous name display rules to be applied (for example "name of a deceased person" warnings)? They are not in the repository.
3. Wording of every new string is placeholder.
