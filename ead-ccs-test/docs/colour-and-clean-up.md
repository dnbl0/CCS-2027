# Explore by colour, Looks similar, and cleaner filters

Approved by the owner on 2026-11-17 (decision 15 in [decisions-2027.md](../../docs/decisions-2027.md)). Inspired by Google Arts &
Culture's colour exploration; nothing was copied from it (no code, images, branding or wording).

## In plain language

- **Explore by colour** (`/explore/colours`): twelve colours (red, orange, yellow, green, teal, blue, purple, pink, brown, black, grey,
  white), each with its name in words and how many records have it. Choosing one opens the search results filtered by that colour.
- **Colour filter**: the same colours in the results sidebar, under Digital Asset Format Type. It is not shown until the index has colours.
- **Looks similar**: on a record page with an image, after More like this, up to eight records whose images have the closest colours,
  as the record page's own cards. It loads when the visitor scrolls near it; with fewer than two records it is not shown.
- **Materials / Medium** filter: "paper, ink" and "oil on canvas" become separate terms ("paper", "ink", "oil", "canvas"), so one
  material is one choice instead of thousands of combinations.
- **Nationality** filter: free text such as "Australian composer and pianist" becomes "Australian"; "Swedish - American artist"
  becomes "Swedish" and "American"; "Born Germany. Lived and worked in Australia" becomes "German" and "Australian". Text that names no
  nationality on the list is left out of the filter and listed for review.

The colours are worked out by a computer from each image, so they are a guide, not a description of the object. Only records whose
image a visitor may see get colours; nothing withheld or sensitive appears in Looks similar.

## Run order (on the owner's laptop)

After any `bin/rails dam:copy_index` and `bin/rails dam:write` (or `dam:sync`), with `DAM_SOLR_URL` set to the DAM sync's own core
([dam-sync.md](dam-sync.md)):

```
export DAM_SOLR_URL=http://127.0.0.1:8985/solr/blacklight-core
bin/rails colour:extract      # downloads each thumbnail as a small PNG and works out its colours (about 8 minutes for 1,800 images)
bin/rails colour:write        # writes the colour names into the core (changed records only)
bin/rails colour:neighbours   # works out Looks similar (seconds)
bin/rails index:normalise     # writes the Materials / Medium and Nationality terms (changed records only)
```

Then restart the site (it checks once, at start, whether the core has the new filter terms). Every task can be run again at any time:
`colour:extract` skips the records already done for the same image (`FRESH=1` does them all again, `LIMIT=20` tries twenty), and the
write tasks send only the records whose fields changed. A new `dam:copy_index` drops these fields as it drops the DAM's: run all four again.

Reports: `colour:extract` prints how many images it read, the colour names it found, and why any failed (list in
`tmp/colour_extract_failures.csv`; a failed image is tried again next time). `index:normalise` prints the most used terms and writes the
nationality values it could not match to `tmp/nationality_unparsed.csv`, for the collections team.

## How it works

| Part | Where |
|---|---|
| Image download (allowlist, small PNG) | `Colour::Fetcher`: only `https` links on `COLOUR_IMAGE_HOSTS` (default `unimelbourne.widen.net`), asked for as `/png/…?w=64`; the site's own `/digital-assets/` files are read from `public/` (JPEGs only when `vipsthumbnail` is installed). No redirects are followed; at most 2 MB |
| Reading the pixels | `Colour::Png`: plain Ruby (zlib). The bundle has no image library (`image_processing` is there without `ruby-vips` or `mini_magick`); adding one means a native library on every machine and CI runner. The DAM converts the image to a 64-pixel PNG itself, so plain Ruby reads it in milliseconds |
| Dominant colours and names | `Colour::Palette`: pixels into 512 boxes, close boxes merged, the groups covering 5% or more are the palette (at most 5); each is named from its hue, saturation and lightness; a record's names are those covering 10% or more |
| Extraction (resumable, rate-limited) | `Colour::Extractor`, `rake colour:extract`, table `record_colours` (record id, image URL, palette, names, 64-box histogram, error, extracted at). `COLOUR_RATE` requests a second (default 4) |
| Writing the index | `Colour::IndexWriter`, `rake colour:write`: `colour_ssim` (names), `colour_palette_ssm` (hex values), `colour_digest_ssi` (changed records only), as Solr atomic updates to `DAM_SOLR_URL` (`WritableCore`). A record no longer viewable loses its colours |
| Looks similar | `Colour::Neighbours`, `rake colour:neighbours`, table `colour_neighbours`: the distance is half the summed difference of two 64-box histograms; up to 16 under 0.6 are kept. `LooksSimilarController` (`GET /catalog/:id/looks-similar`, a Turbo frame, 204 when there is nothing): one database lookup and one Solr request. Partial `catalog/_looks_similar` |
| Colour browse page | `ColoursController`, `ColourCounts` (one Solr facet request), `app/views/colours/index.html.erb`, `components/colours.css` |
| Colour filter | `CatalogConfig::Facets.add_colour_option`: an addition to the workbook's filters (like the Open licence switch), not on the Advanced search form |
| Materials and nationality terms | `Normalise::Materials` (`config/materials.yml`: stop list and synonyms), `Normalise::Nationalities` (`config/nationalities.yml`: each nationality and the words that mean it), `Normalise::IndexWriter`, `rake index:normalise`: `material_term_ssim`, `nationality_term_ssim`, `normalise_digest_ssi` |
| Which field the two filters read | `NormalisedTerms`: the term field when the core has it, otherwise `material_ssim` / `nationality_ssim` as before (a core built by `collections:index`, as in CI). Asked of Solr once at start |
| Wording | `config/locales/colours.en.yml` (placeholder) |

### Accessibility

Every swatch is decoration (`aria-hidden`) next to its colour's name and record count, so colour is never the only cue; the white
swatch has a border. The tiles are one link each, with a visible focus ring, and reflow to one column at 320px. Checked with axe at
desktop and phone width (`test/system/colours_test.rb`).

## Not done here / for review

- `config/materials.yml` and `config/nationalities.yml` are placeholders for the collections team: stop words, synonyms, and which
  words mean which nationality. Cultural identities (for example Aboriginal and Torres Strait Islander peoples) are deliberately not
  on the nationality list; that needs the collections team and Indigenous advisers.
- The colour names and the swatch samples are a first pass; wording is placeholder.
- The test DAM host (`unimelb-test.widen.net`) is not allowed by default; add it to `COLOUR_IMAGE_HOSTS` if wanted.
- Looks similar compares every pair of records: seconds for about 2,000 images; at 20,000 or more, compare within colour names.
- Hosting: the four tasks are run by hand after a DAM sync; nothing schedules them.
