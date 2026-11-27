# Handover: collection stories on record pages (26 Nov 2026)

For the next agent (Copilot or Claude). Read this file, `CLAUDE.md`, `AGENTS.md` and `ead-ccs-test/docs/collection-stories.md` first.
The site owner (Dean) is not technical: give plain-language results, pick the recommended path, and ask before merging.

## Where things are

| What | Where | State |
|---|---|---|
| Stories on record pages (Grainger Museum) | PR #91, branch `design/collection-stories` | Open, CI green at `ca3f093`. **Do not merge until Dean approves the look.** |
| Security update (Ruby 4.0.10, Brakeman 8.1.1, puma 8.1.3, net-ssh 7.3.10) | PR #92 | Merged into `main` |
| Museums Victoria story fetcher (Python) | `scripts/museums-victoria/` on the same branch | Written and run once; not wired into the site |
| Screenshots and fetcher output for Dean | `~/Desktop/CCS stories screenshots/` (OneDrive) | Version 2 is the current design |

## What PR #91 does

- Record pages show "Stories from the collection" when a story's accession number **and** collection exactly match the record.
  Data: `ead-ccs-test/config/collection_stories.yml` (written by `bin/rails stories:harvest`, reviewed, committed; never fetched
  at page load).
- Layout after nga.gov/stories/articles: **one story** is a wide row (site name | "Article" kicker, serif headline, summary |
  picture) between two rules; **two or more** are a card grid (2 columns for 2, 3 for more; 1 on phones).
  `CollectionStoriesComponent` + `CollectionStoryComponent`, `collection_stories.css`.
- Pictures: the story's own first; the Grainger site refuses them to other sites (Cloudflare 403), so
  `story_image_controller.js` swaps in the record's own picture, then falls back to text. Never cropped (`object-fit: contain`).
  Withheld or sensitive records get no picture at all.
- Removed at Dean's request: the record page rows "From the same period" and "More of this type" (`SimilarRows` now has
  creator and place only; `/catalog/:id/similar?row=period|type` is a 404).
- No counts anywhere on the site (Dean's standing rule).

## Open items

1. **Dean's approval of the look** (screenshots in `Version 2 - NGA layout`). Then merge #91 (`gh pr merge 91 --repo dnbl0/CCS-2027 --merge`)
   after merging `origin/main` into the branch and re-checking CI on the latest commit.
2. **Grainger site blocks the harvester and its pictures** (Cloudflare "are you a robot" check, from the cloud and the laptop).
   Do not work around it. Dean was offered an email to the University web team asking them to allow the harvester and
   the pictures. Until then: no new Grainger stories (the Hardanger fiddle story, 00.0099, is missing for this reason).
3. **Curator review**: three matches may be broader than one object (Hirschfield Mack, Ian Bonighton Archive, Melba);
   four stories are unmatched (Christmas Card, Harp Guitar, Dr Kent's Electronic Music Box; Chinese material is held).
4. **Museums Victoria stories (new direction, 26 Nov):** Dean asked to pull stories from the Museums Victoria Collections API
   instead. See below. **Decided (26 Nov, Dean):** the CSIRAC and Engineering objects, their stories and all 20 parent/child
   parts (the run found 20, not 17) become ordinary records in the Engineering and Information Technology Collection, not a
   separate section; Dean has cleared the licences with Museums Victoria. Done by `scripts/museums-victoria/build_harvested_rows.py`
   (adds rows to `ead-ccs-test/data/harvested.csv`, then `bin/rails collections:index_harvested`). The API rate-limits (Cloudflare
   429, about an hour): the script stops rather than retrying; do not work around it.

## Museums Victoria fetcher

`python3 scripts/museums-victoria/fetch_unimelb_stories.py --out <folder>` (standard library only; about a minute).

- API base is `https://collections.museumsvictoria.com.au/api` (the brief's `museumsvictoria.com.au/api` returns 403).
  Every request sends `User-Agent: UniMelbStoriesFetcher/1.0`, pauses 0.2 s, and retries 429/5xx.
- Searches items and specimens for the exact phrases "University of Melbourne" and "Melbourne University" (an unquoted search
  matches ~53,600 unrelated records). Pages through `Total-Pages`.
- **Connected** = the University is named in an ownership/association field (`associations`, `collectionNames`,
  `acquisitionInformation`, `acknowledgement`, credit line, lender). Records naming it only in descriptions or keywords are
  kept separately as "mention only" and not used.
- Fetches linked articles in batches of 40 (`/api/search?id=articles/1,articles/2`), then parent/child articles.
- Output: `unimelb_related_stories.json` (4 MB, full text; not committed), `.md` and `.csv` summaries (committed).

**Result of the 26 Nov run:** 10,295 records name the University; 9,566 are connected (9,499 are specimens in the
"Melbourne University Geology Department Collection"; the rest include CSIRAC, MUDPAC and Engineering School material);
**22 stories** link directly to connected objects (for example "CSIRAC Collection", "Computing Departments at the University of
Melbourne", "University of Melbourne, Faculty of Engineering"), plus 17 parent/child parts that are not themselves about the
University (flagged `fetchedAsPartOf`).

**The catch (resolved, see "Museums Victoria records" below):** these are Museums Victoria's objects, not records in Collections Navigator, so there is no accession number to
match them to our record pages the way Grainger stories are matched. Options to put to Dean: (a) a separate "From Museums
Victoria" list on the relevant collection or Discover page, (b) match by named object where the University holds a related
record (for example CSIRAC or MUDPAC material, if any is in our index), or (c) keep the data for curators only. Check the
Museums Victoria API terms and each article's `licence` before showing their text or images.

## Museums Victoria records (26 Nov, Copilot session)

PR #93 (`design/museums-victoria-records`, base `design/collection-stories`; retarget to `main` once #91 merges).

- **Decision (Dean):** blend the records into the site, no separate section; licences cleared with Museums Victoria; all 20
  parent/child parts (the handover said 17; the data has 20); filed under "Engineering and Information Technology Collection".
  13 of the 20 parts (Immigration Museum "Love" exhibition, Sigalas family, John Gould) are not CSIRAC/Engineering; Dean knows.
- **What was added:** 46 rows in `ead-ccs-test/data/harvested.csv` (source "Museums Victoria Collections"): 19 objects linked to
  the 7 CSIRAC/Engineering stories (1338, 1340, 1348, 1663, 2408, 2511, 3145), and 27 stories (those 7 + the 20 parts). The
  existing `HarvestedSource` indexes them (ids `harvested-items_N`, `harvested-articles_N`), so no Ruby changed.
- **How:** `python3 scripts/museums-victoria/build_harvested_rows.py --stories <unimelb_related_stories.json> [--items-cache f.json]`.
  Story text comes from the fetcher's JSON (copy on Dean's Desktop, `CCS stories screenshots/Museums Victoria stories/`; not
  committed). Only the objects hit the API (batched). Re-running replaces these rows by id. The CSV uses CRLF; keep it, or the
  diff shows every row changed.
- **Rate limit:** a second full fetcher run the same day got Cloudflare 429 (error 1015, Retry-After about 3500 s). The script
  stops on 429. Do not retry around it or run the full fetcher again; reuse the JSON.
- **Not done:** the rows are **not indexed**. Solr was down locally. Run `bin/rails collections:index_harvested` against a
  running core (`docs/solr-dev.md`), then check the records on `/catalog`. Only `bin/rails test test/indexers` ran (63 passed);
  `bin/ci` was not run. No new test (existing `HarvestedSourceTest` covers the mapping).
- **Cloud run:** Dean asked for `/delegate`. That is a CLI command only he can type; not started. Suggested:
  `/delegate --base design/collection-stories ensure bin/rails collections:index_harvested runs against Solr for PR #93`.
  The cloud agent must not use Azure or secrets, so it needs its own Solr.

## Rules that bit during this work

- Branch prefixes `feature/`, `bugfix/`, `enhance/` auto-merge without CI: use `design/`, `chore/`, `discover/`.
- New Stimulus controllers raise the preloaded-script budget in `test/integration/performance_test.rb` (now 62).
- Run Rails tests as CI does: `SOLR_URL=http://127.0.0.1:1/solr/blacklight-core bin/rails test` (local Solr data differs).
- Keep CCS 2026 and 2027 separate; never touch Jira, Azure or secrets; never push to the `org` remote.
