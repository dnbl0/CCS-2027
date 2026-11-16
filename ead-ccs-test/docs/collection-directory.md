# All University collections on the home page

The home page lists every University cultural collection, not only the ones whose records are searchable here. The list is
`config/university_collections.yml` (25 collections: the University Art Collection and the 24 on
museumsandcollections.unimelb.edu.au/collections, read 2026-11-16). Only names and web addresses are kept.

- A collection whose name is in `config/pages.yml` (the five with records in the index) is searched in place.
- The others link to their own website, under "Not in Collections Navigator yet" (placeholder wording).
- `UniversityCollections` does the matching, so a collection moves to the first group by itself once it is added to `config/pages.yml`.
- To add a collection: add it to the YAML (name and address). To make its records searchable: its records have to be in the index
  with that name in `collection_ssim`. That needs the data (an EMu, DAM or CSV load: see `docs/csv-upload.md`) and is the dev team's and the
  collection owner's work.
- Not on the University's page, but in the index: Indigenous Collections (1,540 records) and a few records with other collection names.
  They are not in this list; whether and how to show them is a decision for the collections team and Indigenous advisers.
- Known gap: the Visual Cultures Resource Centre and the MONIAC link to the collections index, not their own pages (no address found).
