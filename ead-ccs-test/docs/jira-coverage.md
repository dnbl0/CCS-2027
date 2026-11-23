# Jira coverage: search and Blacklight tickets

Board: [CCS project, label `CCS-2026`](https://unimelb.atlassian.net/jira/software/c/projects/CCS/boards/6889?label=CCS-2026) (about 140 tickets, re-read on 2026-10-08; the first audit was on 2026-10-06). The Remarks field marks 64 tickets "Feasibility 2026: MVP", CCS-157 "flagged for MVP scope", and seven as not MVP (CCS-19, 46, 52, 53, 55, 62, 158). See the resync section of `jira-mvp-mapping.md` at the repository root. The developers' team has its own
implementation, so a ticket marked **Done** there is not necessarily done in this prototype. Each ticket's
acceptance criteria were checked against the running app (http://localhost:3002), and the ones that
can be checked without Solr are kept as tests (`test/models/jira_search_requirements_test.rb`).

Status key: **Met** (already worked), **Fixed** (gap found and fixed during this audit), **Partial**,
**Gap: data** (needs a source column or export we do not have), **Gap: decision** (the ticket or workbook
is ambiguous), **Not in prototype** (different environment or custom work, parked).

## Search (BR-05) and related

| Ticket | Jira | Prototype | Notes |
|---|---|---|---|
| CCS-33 Basic search | Done | **Met**, with the gaps **Fixed** | Search box on every page; results in list view by relevance; a blank or whitespace search returns all 40,962 records (the updated criterion); no-results message per CCS-124. Fixed: queries are cut to 255 characters (server side and `maxlength` on the header inputs), and special characters are not allowed: `QueryRules` keeps letters, digits, spaces and the characters CCS-34 and real names need (quotes, parentheses, apostrophe, comma, full stop, hyphen, ampersand) and replaces everything else with a space, telling the visitor. A search of only special characters (`***`, `*:*`) returns to the home page asking for "a valid search string". This also stops Solr query syntax (`*:*`, `field:value`, `[a TO b]`, `{!...}`) reaching Solr. |
| CCS-34 Boolean / exact phrase | Done | **Met** | `AND`, `OR`, `NOT`, nested parentheses, quoted phrase in order (28 hits; reversed order 0; unquoted 36), operators are capitals only. |
| CCS-37 Search within a Collection | Done | **Met** | Collection Title filter; one or several collections; keyword search within a collection. |
| CCS-38 Search filters | New | **Partial** | 13 of the 22 workbook filters (see `docs/data-model.md`). The other 9 are **Gap: data** or open questions. The ticket's table differs slightly from the workbook (it lists "Object's Place of Production" and "Object classification"; the workbook has Region and Classification). |
| CCS-20 Filter and refine | New | **Met** | Multiple filters, results limited to them, keyword search within filters, add or remove filters at any time (constraints). |
| CCS-41 Digital assets only | New | **Fixed** | The workbook's "With Digital Asset" filter (Yes / No), after Digital Asset Format Type in the Media type section. |
| CCS-55 Indigenous data filter | New | **Gap: data** | The flag's source field is "tbd" for EMu, Vernon and FEIT in the ticket itself; Nexus DAM "DA Indigeneity data" has no export. |
| CCS-45 Pagination | Done | **Met** | Total count, per-page 12/24/40/96 (default 40), numbered pages (jump to any page). |
| CCS-116 Semantic search | Done | **Fixed** | Was not implemented here: `synonyms.txt` was Solr's sample file. Now a query-time synonym filter with the static prototype's curated vocabulary (30 groups; 19 general words that find their specifics). Specific words do not widen to general ones (that matched every "Medical" record). Reload the core, no reindex. |
| CCS-123 Fuzzy search | Done | **Met** | A misspelled word returns results for the corrected word. |
| CCS-158 Spelling suggestions | Done | **Met** | "No results for skul. Showing results for skull instead. Did you mean: ..." |
| CCS-288, 292, 293 Spelling bugs | Done | **Met** | Last word misspelled, phrase with a misspelling, partial phrase: all correct and offer alternatives. |
| CCS-124 No results message | New | **Fixed** | Now "No results found and no suggestions are available for this search phrase." |
| CCS-271 Empty search | Done | **Met** | Superseded by CCS-33's updated criterion: an empty search returns everything. |
| CCS-143 Save search history | New; label `CCS-2027`, de-prioritised for MVP by the business (comment, 16 Oct) | **Met, native** | Blacklight's built-in search history, unmodified: saved in the session, no login, the `/search_history` page with Clear history. The search overlay lists the last 5. The session cookie lasts 30 days (it also keeps saved records), so history outlasts the browser; the story says session only. |
| CCS-206 History grouped by day | New; label `CCS-2027`; Remarks: not core for MVP | **Not in prototype** | Removed: the custom day-grouped page. The history page is Blacklight's own, ungrouped. |
| CCS-46 Favourite lists | New | **Partial** | Save / Saved on every result and record, a live "N saved records" bar in the header and a Saved records page, using Blacklight's bookmarks for guests (session cookie, 30 days, no login). One list only: several named lists, logging in and keeping the list across devices are **Not in prototype**. |
| CCS-19 Explore collections | New | **Partial** | The header lists the five collections and filters by them. There are no collection landing pages (removed by decision, 2026-10-16): a collection's link goes to the results filtered by it. |
| CCS-44 Viewing classification | New | **Gap: data** | Source is "DA Advisory Classification" in Nexus DAM. |
| CCS-217 Collection asset details | New | **Partial** | The record page follows the workbook's fields (19 of 30 have data); events, measurements, language and provenance are **Gap: data**. |
| CCS-310 Test semantic search with integration data | New | **Not in prototype** | Depends on the developers' integration data. |

## Data pipeline tickets (BR-18, integration)

CCS-159, 169, 185, 197, 207, 209, 265, 266 (index create, update, delete for EMu, Vernon, Nexus DAM) and
the "CCS integration with ..." tickets describe the developers' pipeline (webhooks, S3, database
records). This prototype loads the CSV exports with `rails collections:index` (a full or repeat load;
rows removed from a CSV are not deleted from the index). Nexus DAM has no export.

## Not search tickets, noted

CCS-50 (Acknowledgement on the home page) is present. CCS-51 and 62 (accessibility): axe reports no WCAG 2.1 AA
violations on the results, record and advanced search pages.

## 2026 MVP recheck (2026-10-08)

| Ticket | Jira | Prototype | Notes |
|---|---|---|---|
| CCS-65 Digital asset formats | New, MVP: images, audio, video, PDF (2027: eBook, Office, Open Office, 3D) | **Partial** | Only still images are indexed and shown (`Collections::DigitalAssets`, `FORMAT = "Image"`). Audio, video and PDF are not met in this app; the static site has viewers for all four. |
| CCS-157 Hero image | New, flagged MVP | **Partial** | A thumbnail shows in results and the record. Not implemented: the hero chosen by DAM sequence `000` (CCS-302, CCS-316), the source ordering of the other images, and the 20-asset cap per record. |
| CCS-206 History grouped by day | `CCS-2027`; not core for MVP | **Not in prototype** | Was built ahead of the board; removed so the history page is Blacklight's own. |
| CCS-55 Indigenous data filter | New, not MVP, data not ready | **Gap: data** | Unchanged. |
| CCS-158 Spelling suggestions | Done, but Remarks say not MVP | **Met** | Built regardless. |

## Board audit, 23 Nov 2026 (labels CCS-2026, CCS-2027, MVP; 250 issues) and the 2027 backlog prioritisation

Read against the code and the running site (:3085) and against "CCS 2027 Backlog - Prioritisation.xlsx" (reviewed 23/11/26).
Jira was read only.

Fixed in this prototype on 23 Nov 2026:

| Ticket | What was missing | Now |
|---|---|---|
| CCS-482 shared mailbox | The Help page named collections-navigator@ | coll-navigator@unimelb.edu.au; the museum pages' mhm-info@ corrected to CCS-47's mhm.info@ |
| CCS-233 contact page | Email addresses shown plainly | Every address in an HTML page written with character references (lib/middleware/email_protection.rb): shown and clickable as before, absent from the raw HTML |
| CCS-36 PDF full text | No "Not indexed" message | A PDF with no readable text is named at indexing and its viewer says a search will not find words inside it (OCR stays out of scope) |
| CCS-53 activity reporting | Reporting is Adobe Customer Journey Analytics, outside CCS | The Adobe tag loads when ADOBE_ANALYTICS_SCRIPT_URL is set, only after the visitor accepts analytics cookies (CCS-471) |
| CCS-31 CSV upload | Removing an uploaded set | records:remove_csv (full or partial); the upload stays a back-end operation (criterion 7) |
| CCS-295 to 299 collection pages | Lorem ipsum introductions | Draft introductions for the five museums, from their own sites, marked for approval |
| CCS-164 formats 2027 | Office, OpenOffice, eBook, 3D not shown | Office and OpenOffice: a LibreOffice PDF preview made at indexing, its text searchable. eBooks read a page at a time in the page (epub.js) and glTF/GLB 3D models turned and zoomed in the page (Google model-viewer), both approved and installed 23 Nov 2026 |

| CCS-40 search results selection | Browsing the selection "randomly" | Shuffle the order on Selected records; the list and each record's Previous and Next follow it; Back to the order you selected |
| CCS-137 citations, list view | Export to a Word document "without losing the format" | Download as a Word document (.docx, built with no extra library): titles in italics, the style's heading, a hanging indent; the page shows the italics too |

Every other Must, Should and Could ticket of the worksheet, checked against its acceptance criteria on 23 Nov 2026:

| Met in this prototype | |
|---|---|
| CCS-143, 206 | Search history (Blacklight's), not grouped by day (Should, not core) |
| CCS-47, 501 | Contact us from a record, the collection's own address |
| CCS-131, 489 | Record citations: APA, MLA, Chicago, Harvard, copy |
| CCS-58, 498 | Compare: two or more images or records side by side, zoom and pan each, details, exit, choose others |
| CCS-56 | Multilingual search: ICU folding and CJK bigrams in the Solr schema; values shown as the source has them |
| CCS-112 | records:suppress / records:unsuppress for the administrator (no CM login, as the story says) |
| CCS-163, 503 | Metadata CSV export for open records |
| CCS-69 | Request to view: the asset withheld, the notice, the request link (AccessPolicy, AccessNoticeComponent) |
| CCS-21, 227, 487 | Sensitivity notice; the media hidden until Continue to view (SensitivityGateComponent) |
| CCS-44, 496 | Classification badge (ClassificationBadgeComponent), once the DAM sends DA Advisory Classification |
| CCS-425 | A replaced DAM file shows at once: its address carries a version (AssetVersion, ?v=) |
| CCS-481 | Audio and video formats a browser cannot play offer the file or a request (MediaTypes) |
| CCS-39, 492 | Matched words highlighted and a "Matched in" line (SearchHighlighting) |
| CCS-101 | Contextual help (Done in Jira) |
| CCS-127 | AI and bot crawlers: robots.txt, X-Robots-Tag and the bot guard middleware |
| CCS-128 | SEO basics: one h1, ordered headings, page titles, canonical links, structured data |
| CCS-471, 506 | Cookie notice for guests, with optional analytics (CCS-53) |

| Not for the prototype to build | |
|---|---|
| CCS-145 security, 172 WAF, 144, 146, 147, 148, 71 | Hosting and operations (the Azure and University teams); the app's own part (CSP, request limits, bot guard) is in place |
| CCS-249, 232, 161, 119, 168, 351, 210, 208, 12 | EMu (FEIT) and other source-system integrations: the data teams |
| CCS-4 curated content, 113 permissions | To be sized by the tech team; 113 is Done in Jira |
| CCS-472 site entry point | An information architecture decision for the University web team |
| CCS-51, 62, 505 accessibility, 63, 504 responsive | axe-clean at every width in CI; a screen-reader test by people is still needed |
| CCS-57, 315 IIIF | The viewer reads IIIF when a record carries it; the DAM field (CCS-315) is the data team's |

Not built, by the worksheet's decisions: sign-in and signed-in features (CCS-59, 60, 61, 129, 130, 136, 13: Won't), bulk download
(CCS-167: Won't). Still blocked on data: CCS-55 (no Indigenous data flag) and CCS-35 (no language field). Worksheet decisions that
differ from this prototype, for the team to settle: CCS-67 marks DA download "Won't" (the prototype downloads open images), and
CCS-448 is a Must while CCS-522 (remove the MDHS Indigenous creator fields) is Done.
