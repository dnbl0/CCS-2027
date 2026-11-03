# Similar records, Featured, Pick of the day and Trending

Four ways into the collections that do not need a search. They sit on the record page (Similar records), the home page and
`/discover` (Featured, Pick of the day, Trending).

## In plain language

- **Similar records**: at the foot of a record page, up to six records that share its creator, subject, type of object or place.
- **Featured**: records the collection teams chose (`config/featured.yml`).
- **Pick of the day**: one record with an image anyone may download, chosen by the date, the same for everyone all day.
- **Trending**: the records opened most often in the last seven days. The site counts page views per record per day and nothing about
  who looked (no cookie, address, session or browser details). Until enough records have enough views the section is not shown and
  Featured stands alone.

No record whose asset is withheld, or that is marked sensitive, appears in any of them, and none is counted.

## How it works

| Part | Where |
|---|---|
| Shared rules (who may be listed, the fields asked for, the Solr call) | `app/models/discovery.rb` |
| Similar records query | `app/models/similar_records.rb`, `SimilarController` (`GET /catalog/:id/similar`, a Turbo frame, 204 when there is nothing) |
| View counter | `app/models/record_view.rb`, table `record_views`, `app/controllers/concerns/counts_record_views.rb` |
| Trending, Featured, Pick of the day | `trending_records.rb`, `featured_records.rb`, `discover_sections.rb` |
| Pages | `DiscoverController`: `/discover` and `/discover/frame` (what the home page loads) |
| Wording | `config/locales/discover.en.yml` (placeholder) |

The record page and the home page load their sections lazily, so the record page still makes one Solr request and the home page
HTML (budget 56 kB) and Solr use are unchanged. A failing Solr or database leaves the section out; it never breaks the page.
(There is no circuit breaker in this branch; each call fails fast on its own timeouts and the section degrades to nothing.)

### Similar records: the query

Solr's More Like This parser (`{!mlt}`, built into `/select`) with `qf` creator 3, subject 2.5, object type 2, classification 1.5,
title 1.5, cultural group 1.5, place 1, associated subject 1, collection 0.3; `mintf=1 mindf=2 maxdf=8000 maxqt=25`. Two optional
clauses nudge the order: a digital asset (+6) and a start date within 25 years (+4). The record is excluded; weak matches (under
35% of the best score), withheld and sensitive records are dropped; at most three records of one creator; under two results hides
the section. Parameters are named `sim_*` because a parameter called `mlt` switches on Solr's MoreLikeThis component.

**Solr configuration: none needed.** The parser is built in, uses stored values, and needs no reindex or config reload. (A
dedicated handler or term vectors on the text fields could make it faster later; both need a reindex.) The private Solr container
mentioned in the brief was therefore not needed: the shared one was only read.

### Trending: what is stored and when

`record_views(document_id, day, views)`. A request counts when it is a successful HTML GET with a browser-like user agent (not a
crawler, library or monitor by name, not blocked by `BotControls`, not a prefetch) for a record that Discovery lists (open or
view-only, not sensitive). Counts are held in memory and written in one upsert every 60 seconds, every 200 different records, or at
exit, so the record page does not wait for the database. A process killed abruptly loses up to a minute of counts.

Settings (`docs/configuration.md`): `TRENDING_ENABLED` (on), `TRENDING_DAYS` (7), `TRENDING_MIN_VIEWS` (3), `TRENDING_KEEP_DAYS` (35).

**Schedule** `bin/rails record_views:prune` once a day (for example an Azure Container Apps job or cron at 03:00). Without it the
table grows by at most one row per record per day.

### Pick of the day

The date is hashed (CRC32) to a position among records with a thumbnail and the licence "Public domain - Copyright expired"
(ordered by id), then checked with `AccessPolicy` (tier `:open`) and `Sensitivity`; the next few are tried if it fails.

## Relevance evaluation (4 Nov 2026, the 40,962-record local index, 134 of them with images)

Judged by eye: the top three of the cleaned list.

| Record | Top results | Verdict |
|---|---|---|
| emu-406126 Percy Grainger portrait (de Meyer, 1901) | Two more de Meyer portraits, then Dover Street Studios and Holten portraits of Percy Grainger | Good; the creator cap (3) stops one series filling the list |
| emu-20335 painting, Rusty Peters | Two other Rusty Peters paintings, then Country-themed paintings by Muffler, Carnegie | Good |
| emu-400198 Nagoya harp | Orchestral harp, two Mountain Harps, harp guitar | Good |
| emu-10133 drawing, Derwent Lees | Another Lees, then "Portrait of a Girl" drawings by other artists | Fair: title words dominate when the creator has few records |
| vernon-MHM01073 invitation (Medical History) | Invitations of the same year and printer, Hewlett papers | Good |
| vernon-HFA2892 dental teaching model | Three sibling teaching models | Good but only 3 exist |
| vernon-516-500028 wallaby photograph | Other Wood Jones wallaby photographs | Good |
| emu-401234 Grainger archive item | Other "Grainger:" archive items | Fair: generic titles |
| emu-10247 von Guerard lithograph | Duplicate impression, Mount Eccles, Quarry Ferntree Gully | Good |
| emu-407747 Percy and Ella at Pevensey | Photographs of Percy and Ella Grainger | Good |
| vernon-MHM2014.191 (sensitive) and emu-108756 (ICIP) | no section, by design | Correct |

Weak spots: records with no creator, subject or type fall back to title words only; the index has few images, so the image nudge
rarely changes the order here.

## Open questions

- Retention of the counts (35 days is a placeholder for the privacy office).
- Blurbs and section wording in `config/featured.yml` and `discover.en.yml` are placeholders.
- Real data will have far more imaged records; revisit `MIN_SCORE_RATIO` and the weights then.
