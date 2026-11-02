# The web app only reads Solr; the University dev team owns the index and its schema

While serving visitors the app only searches: it never adds, changes or deletes a record (the sitemap reads ids by cursor, the
browse menu counts, record pages fetch one document). The Solr schema and `solrconfig.xml` (`ead-ccs-test/solr/conf`), the
fields in the index and the University's ingest from EMu, Vernon and the DAM belong to the dev team, and the app is built
against what the index holds. `Collections::Indexer` and `bin/rails collections:index` fill a core from the committed CSV
exports for development, CI and the Azure demo; they are not the production ingest.

## Consequences

Anything the app needs from the data is asked for as a field the ingest provides, and `config/data_model/solr_mapping.yml` says
which workbook field maps to which Solr field, or why none does yet (a `gap:`). The app does not invent values to fill a gap.
A schema change is the dev team's, and the core must be recreated and reindexed (README, "If changes are made to Solr schema").
Tests that read Solr call `needs_solr` and skip when none is reachable. Search behaviour and facets (`SearchBuilder`, `solrconfig.xml`) are changed with the dev team, not alone.
