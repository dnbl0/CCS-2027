# The Rails/Blacklight app is the product; the static site is a prototype

The live site is the Rails/Blacklight app in `ead-ccs-test/`, searching Solr. The static pages in `public/` came first, as a
prototype with an in-browser copy of the data and its own search, and are still published to GitHub Pages. Copy and styling are
kept in step between the two (`scripts/sync-partials.js`, `scripts/sync-rails-assets.js`, and the since-removed `scripts/parity.js`), so a change to
the pages is made in both. New behaviour is built in the Rails app first.

## Consequences

The pairing roughly doubles the cost of every page change. Retiring the static site would remove the sync and parity scripts,
the mock search and the second token set; it needs the product owner to confirm that nobody relies on the GitHub Pages site.
