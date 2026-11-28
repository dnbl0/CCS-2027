# Removing a record (CCS-112)

When a record has to come off the public site quickly (a request from a family or community, legal advice, a mistake in the
source data), staff take it out with a command. The record disappears from every page and answer; its address says "removed"
(HTTP 410 Gone). Nothing is deleted: lifting the removal brings the record back.

There is no staff sign-in yet, so there is no admin page. The commands run on the server, like `access_requests:export`.

## The commands

```
bin/rails "records:suppress[emu-9044,Removed at the family's request, 2026-11-16]"
bin/rails "records:unsuppress[emu-9044]"
bin/rails records:suppressed
```

- `records:suppress[ID,reason]` takes the record out. The reason is required and is kept (commas are fine in it). Run again, it
  changes the reason and nothing else (the date of the first removal stays), so it is safe to repeat.
- `records:unsuppress[ID]` puts the record back. Safe to repeat.
- `records:suppressed` lists what is removed, as CSV: id, when, who, why. A reason that starts like a spreadsheet formula is made safe.
- `SUPPRESSED_BY=<name>` says who did it (free text; the server's user name when unset).
- An id is letters, digits and `. _ : -` (at most 200 characters). Anything else is refused.

The list is the `suppressed_records` table (`SuppressedRecord`).

## How fast, and what happens

A running server reads the list from the database and keeps it in memory for `SUPPRESSED_RECORDS_CACHE_SECONDS` (30 by
default; the server that made the change sees it at once). So a removal reaches every instance within half a minute, with no
restart, no reindex and no deploy. Cached pages that hold record counts (the header menu, Explore, the browse pages, Related
objects, the sitemap's list) include the list in their cache key, so they are rebuilt without the record instead of being kept
for a day.

## Where it is applied: one seam

`SuppressedSolrFilter` (`lib/suppressed_solr_filter.rb`) is prepended to `RSolr::Client`, the client every Solr request in the app
goes through, and adds `-{!terms f=id}id1,id2` to each search. So it covers, without each page remembering to ask:

- the results page, its counts, facets and the facet "more" lists, and the record page's own fetch;
- Discovery (Featured, Trending, Pick of the day), Similar records, Related objects, record cards, entity pages (`Browse::Profile`),
  the browse hubs, the header menu's counts, and the sitemap;
- saved records, lists, galleries, the selection, the comparison and bulk downloads: a removed record is **left out quietly**
  (the saved-records count leaves it out too), the rest of the list works as before.

Solr's admin, update and suggest handlers are not searches and are left alone. A long list (over about 1,500 bytes of filter) makes
the request a POST so the address stays short.

`test/integration/record_removal_test.rb` fails if a Solr request from any of those paths lacks the filter, and if any code builds
its own connection to Solr (`RSolr.connect`, `Net::HTTP`...) other than the two listed there (the indexer writes, the readiness
probe pings). A new way of asking Solr has to go through the client, or the test says so.

## What a visitor or a crawler sees

The pages that **name** the record answer **410 Gone**: its record page, citation and Similar records, the metadata export, the IIIF manifest (no body), the sensitivity choice, the comparison and the access request
form, the embed (a short message inside the frame) and oEmbed (no body). The page is the site's error page ("This record has been
removed"), `noindex, nofollow`, with no title, description, image, structured data or asset address. A search engine that
asks for the address learns the record is gone for good, which is the quickest way for it to drop the page.

The wording is **placeholder**: the University decides it (`app/views/errors/show.html.erb`, `config/locales/galleries.en.yml`,
`public/410.html`).

## What this does not do (needs the dev team or the University)

- **The Solr index still holds the record.** It is filtered at query time. The collection systems (EMu, Vernon) and the index
  need the record changed or removed for it to be gone for good; a reindex from a source that still has the record does not
  bring it back to the site while it is suppressed.
- **Search-box suggestions.** The suggester (`/catalog/suggest`) is built from the index and cannot be filtered per record; a
  suppressed record's title words can still be offered until the suggester is rebuilt without it. Rebuild it after removing the
  record from the index (the dev team).
- **Files under `public/digital-assets/`** are served to anyone who has the file's address. No page names that address any more,
  but the file stays until the real digital asset system or the dev team removes it.
- **Copies elsewhere**: search engines' caches (a 410 and a removal request in their webmaster tools speed this up), other sites
  that embedded the record (they get the 410 message), and exports or downloads already made.
- **Who may remove a record, and the written process, wording and consultation** are University decisions (see
  [compliance-register.md](compliance-register.md)). The app only makes the removal possible, quick and recorded.
- If the database cannot be read, a server keeps the last list it read. A server that has never read it shows every record until the
  database is back; `/readyz` already fails when the database is down.
