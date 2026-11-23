# Explore by time and by place

## In plain language

Two new pages let visitors start from **when** and **where** instead of a search box (approved by the product owner on
2026-11-17, [decision 14](../../docs/decisions-2027.md)). The idea comes from Google Arts & Culture's "explore by time" and map;
no code, pictures or wording were taken from it.

- **`/explore/time`**: a strip of centuries, earliest first (years before 0 are "BCE"), each with its number of records and up to
  three pictures. Choosing a century opens its records in the search with the year filter set; "Decades" shows the ten decades of
  that century the same way. Below it, **eras** as they are catalogued ("19th century", "5th century BC") as buttons. With a
  keyboard, the left and right arrow keys move between periods (Home and End to the first and last); without JavaScript it is a
  plain list of links. On a phone the strip becomes a list.
- **`/explore/places`** (after Airbnb's search with a map, 2026-11): the places as picture cards (`Explore::PlaceCards`: the places with
  the most pictured records, `Browse::Cards.map_cards`, joined by name to their pins) beside a map with each place's number of records
  on its pin (places close together are grouped; choose a group to zoom in, a place for a small card linking to its page). Region chips
  and a name box narrow the cards and the pins; once the map is shown the cards are the places in view ("Update the list as I move the
  map"), with the places in view that have no picture listed by name under them. Hovering or focusing a card marks its pin. Under it
  all, every region, country and place as lists. The cards share one square shape (each picture whole on a pale mount) and come 18 at a
  time; before the map is loaded its panel shows the places as dots drawn from the page's own data; on a phone the list comes first
  and a floating button swaps the list and the map. **The map only loads when the visitor presses "Show the map"**, because its pictures come from
  OpenStreetMap's server. Until the places have been located (below), the page shows lists of regions and places instead of a map.
- **A "Place" filter** in the search results: Region > Country > State > Place, opened step by step. It sits straight after the
  workbook's Region filter (#14) and is an **addition**, not one of the workbook's filters. It appears once the index has the data.

Every list opens the normal search (`/catalog`) with a filter: there is no second search. Wording is placeholder until the
collections team approves it.

## What the owner runs, in order (on your own computer)

The index has no coordinates, so the places are looked up once with **OpenStreetMap Nominatim** and kept in the database table
`place_geocodes`. Nothing is looked up by the live site. Run these in `ead-ccs-test`, with the DAM sync's own Solr core running
([dam-sync.md](dam-sync.md)):

1. If you have just made a fresh copy of the index, run `bin/rails dam:copy_index` (and `dam:sync FULL=1`) first, as usual.
2. Create the table once: `bin/rails db:migrate`.
3. Look the places up (about 1,800 places at one a second: **about 30 minutes** the first time; later runs only ask about new places):

   ```
   SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core bin/rails geo:geocode
   ```

   `DRY_RUN=1` first shows how many would be looked up, changing nothing. `LIMIT=20` stops after 20 (a trial). If it stops
   (laptop closed, network down) just run it again: it carries on. At the end it prints how many were found, not found and failed;
   failed ones are asked again next time, "not found" ones are not.
4. Write the results into the DAM core:

   ```
   DAM_SOLR_URL=http://127.0.0.1:8985/solr/blacklight-core bin/rails geo:write
   ```

   It refuses to run without `DAM_SOLR_URL`, and never writes to the shared core. Only records whose places changed are written.
5. Run the site on that core (`SOLR_URL=$DAM_SOLR_URL`, as in dam-sync.md) and open `/explore/places`.

After a new `dam:copy_index`, run step 4 again (the copy drops these fields; the lookups are kept, so step 3 is not needed).

## What is written to each record

| Field | Example | Used by |
|---|---|---|
| `place_latlon_llsim` | `-37.81360,144.96310` | Spatial queries (the schema's `location` type: `{!geofilt}` works; no schema change needed) |
| `place_geo_ssim` | `-37.81360,144.96310\|Oceania\|Australia\|Victoria\|Melbourne` | The map's markers (one facet request) |
| `place_country_ssim`, `place_state_ssim` | `Australia`, `Victoria` | Facets, if wanted later |
| `place_hierarchy_ssim` | `Oceania`, `Oceania\|Australia`, `Oceania\|Australia\|Victoria`, ... | The Place filter and the lists |
| `geo_digest_ssi` | a hash | "Has this record changed?" |

The region is the commonest `region_ssim` of the place's records, or, when they have none, the continent of the country
(`config/geo/continents.yml`). A place that is itself a continent ("Oceania") is a filter level, not a map marker. Two spellings of one
place ("[Melbourne]" and "Melbourne") share one lookup. A wrong answer can be corrected in `place_geocodes` (set `source` to
`manual`) and written again with step 4.

In the search sidebar the Place filter is a drill-down: regions and their countries are drawn, and the states and places under a
country only once that country (or something in it) is chosen. Drawing every level (1,384 values) took most of a results page's time.

## Privacy and third parties

- **Geocoding** (owner's machine only): only the place text is sent to Nominatim, at most one request a second, with a User-Agent
  that names the application (`GEOCODER_USER_AGENT`), never a person or an email address. Results are cached, as the
  [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/) asks.
- **Map tiles** (visitors): the browser fetches tiles from `tile.openstreetmap.org` (`MAP_TILE_URL`) **only after** the visitor
  presses "Show the map" (the page then remembers that choice in the visitor's own browser, `localStorage` key `ccs:place-map`, until
  they press "Hide the map"). The host is named in the Content Security Policy; the OpenStreetMap credit is shown on and under the map;
  `/privacy` says what that server receives (placeholder wording, for the University to approve). The OpenStreetMap Foundation's tile
  server is meant for light use: production should use a tile service the University has an agreement with (set `MAP_TILE_URL` and
  `MAP_TILE_ATTRIBUTION`).
- **Leaflet** (the map library, 1.9.4) is vendored (`vendor/javascript/leaflet.js`, BSD-2-Clause), served by the site, and loaded
  only when the map is opened. No CDN.

## How it is built

- `ExploreController` (`/explore/time`, `/explore/places`), `Explore::Timeline` (one range-facet request on `date_start_isi`, and one
  grouped request for pictures that a visitor may see: `AccessPolicy.view?`, not sensitive), `Explore::Places` (one facet request).
  Both are cached for hours with a last good copy for a month (`Explore::Cache`); with Solr down and nothing kept, a plain 503.
- `Geo::Nominatim`, `Geo::Geocoder` (`rake geo:geocode`), `Geo::SolrWriter` (`rake geo:write`), `Geo::Hierarchy`, `PlaceGeocode`.
- `NexusCcs::PlaceHierarchyFacetComponent`: Blacklight's own facet items, nested, with native disclosures (`<details>`).
- `timeline_controller.js` (arrow keys), `place_map_controller.js` (map, grouping, popups), `components/explore_pages.css`.

## Accessibility

- The map is optional: every place on it is also a link in the lists beside it, with its count. The show/hide button is a
  disclosure (`aria-expanded`, focus stays on it). On the map, markers are buttons in the Tab order named "Melbourne: 120 records";
  a popup's link takes the focus and the marker gets it back when it closes; the arrow keys pan and + and - zoom (Leaflet's own).
  Animations are off for visitors who ask for reduced motion.
- The period strip is an ordered list of links; pictures in it are decorative (`alt=""`), the link says the period and count. No
  horizontal page scroll at 320px; targets are 44px.
