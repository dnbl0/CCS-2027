# Solr for development

This app has its own Solr core, built from `solr/conf` and indexed from `data/*.csv` by
`Collections::Indexer`. Do not point it at a Solr that another project uses: its schema
(this app defines the M&C fields) and `solrconfig.xml` differ, and the two apps would overwrite
each other's documents.

```sh
# Solr 10 (the schema targets luceneMatchVersion 10) on a port of your choice, e.g. 8984
bundle exec solr_wrapper -p 8984          # uses .solr_wrapper.yml: core "blacklight-core" from solr/

export SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core
bundle exec rails collections:index        # ~20 s for ~41,000 records; FORCE=1 to reindex
bundle exec rails server -p 3002
```

`config/blacklight.yml` and the indexer both read `SOLR_URL`, defaulting to
`http://127.0.0.1:8983/solr/blacklight-core`.

Chinese, Japanese and Korean search needs the CJK fields in `solr/conf` (see [multilingual-search.md](multilingual-search.md)); a core made before that needs the configuration applied and a reindex.

After changing `solr/conf` or the indexers, recreate the core (or `rails collections:clear`) and
reindex. The index is stale if a facet defined in `CatalogController` does not render: compare the
fields the indexers emit with the controller's fields before changing the controller.

## System tests

`bin/rails test:system` drives a real headless Chrome (Cuprite, over the DevTools protocol, so no chromedriver has to
match the Chrome version) through the main journeys: search from the home page, the view buttons, filtering, opening a
record, the advanced search panel, the phone menu and the Acknowledgement of Country. They need the Solr core above,
indexed, at `SOLR_URL`. Set `BROWSER_PATH` to a Chrome or Chromium that is not on the PATH. In CI the `system` job in
`.github/workflows/rails-ci.yml` downloads Solr, creates the core from `solr/`, indexes `data/*.csv` and runs them.
