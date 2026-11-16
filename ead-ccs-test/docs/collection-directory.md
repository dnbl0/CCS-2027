# All University collections on the home page

The home page lists every University cultural collection, not only the ones whose records are searchable here. The list is
`config/university_collections.yml` (25 collections: the University Art Collection and the 24 on
museumsandcollections.unimelb.edu.au/collections, read 2026-11-16). Only names and web addresses are kept.

- A collection is searched in place when it has a landing page in `config/pages.yml` OR the index holds records whose `collection_ssim`
  is its name. The others link to their own website, under "Not in Collections Navigator yet" (placeholder wording).
- So when a collection's records are loaded, it moves to "search here" by itself within an hour (the counts are cached; a Solr outage
  is not cached, and then only the landing-page collections are searchable). No code change is needed.
- Its search is the `collection_ssim` filter, with the default "with images" filter off, so every record shows, with or without images.
  A search typed on that results page stays inside the collection (the search form carries the filter), and the collection also appears
  in the Collection facet.
- **The loaded records must carry the collection's name exactly as written in `config/university_collections.yml`** in `collection_ssim`
  (the CSV column `collection`; EMu and DAM loads use their own field). If the data spells it differently, add `facet_value: <spelling>`
  to that entry. A landing page (banner, blurb, named collections) is optional and is added in `config/pages.yml`.
- To add a collection: add it to the YAML (name and address). To make its records searchable: its records have to be in the index
  with that name in `collection_ssim`. That needs the data (an EMu, DAM or CSV load: see `docs/csv-upload.md`) and is the dev team's and the
  collection owner's work.
- Not on the University's page, but in the index: Indigenous Collections (1,540 records) and a few records with other collection names.
  They are not in this list; whether and how to show them is a decision for the collections team and Indigenous advisers.
- Known gap: the Visual Cultures Resource Centre and the MONIAC link to the collections index, not their own pages (no address found).
