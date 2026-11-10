# Decisions made for the 2027 discovery features

These are the open questions the work on galleries, embeds, similar records, trending, entity pages, advanced search and de-bias
left behind, with the answer taken for each and the reason. They were decided on behalf of the product owner so work could go on;
each can be changed. **Plain-language summary first.**

## In short

- Seven questions are decided and built or kept as they are.
- Two cannot be decided by the product owner or by the developers, so they stay open on purpose: **the legal and privacy
  wording** (it has to come from the University's privacy, legal and accessibility owners) and **the de-bias term list** (it has to
  come from the collections team and Indigenous advisers). Both are marked in the pages and listed below so nothing is mistaken for
  approved text.

## Decided

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Who may embed a record or gallery on another site? | Any site may frame `/embed/*` by default. Production can narrow it with `EMBED_FRAME_ANCESTORS`. | The embed carries what the public record page already shows, with the same access rules (a withheld or sensitive record gets a notice, never an image), no script, no cookie and no owner. A closed default would make the embed code useless for the people it is for. Narrowing is one setting. |
| 2 | How long are trending view counts kept? | 35 days (`TRENDING_KEEP_DAYS`), and the table now **prunes itself**: the first counter flush each day removes older rows. | The trending window is 7 days (`TRENDING_DAYS`), so 35 covers any window up to 30 days with margin and keeps the table small. A self-pruning table needs no scheduler, and no scheduler exists until hosting is decided. The counts hold no personal data in any case (a test checks the columns). |
| 3 | Related objects (from #24) or Similar records? | Keep both. | "Related objects" answers "what else is of this type, by this maker, on this subject or from this place" (a plain match). "Similar records" ranks by weighted resemblance and loads later. They can overlap, and that is acceptable for now; the Similar section is a lazy frame, so it costs the record page nothing if it is removed. Revisit after the pages have been looked at with real use. |
| 4 | Does oEmbed name a withheld or sensitive record? | No. The oEmbed `title` and the iframe's `title` use a generic line for these records (`EmbedCode::GENERIC_TITLE`). | Search metadata already hides these titles (`PageMeta`). oEmbed is read by other sites and aggregators, so it should follow the same rule. The embed card itself still carries the notice. |
| 5 | Label of the reuse switch. | Keep **"Open licence (public domain)"**. | It says only what is true: the records whose licence is public domain, the one open tier. "Free to reuse" would be a legal claim. Wording stays placeholder (see below). |
| 6 | How many extra rules in Advanced search? | 8 extra rows beyond the five fixed fields. | Enough for any real query; a hard limit keeps the form and the Solr query bounded. |
| 7 | Which records get entity pages and enter the sitemap? | Makers, places, subjects and periods. A page is in the sitemap only with 5 or more records; thinner pages are `noindex, follow`. Object types still open the search; collections have no entity page. | Thin pages are low value to a searcher and to a search engine. Object types and collections are already well served by facets and the home Explore tiles. |

## Not decided on purpose (needs the University)

| Item | Who decides | Where it shows | What is in place |
|---|---|---|---|
| Legal and privacy wording | The privacy, legal and accessibility owners | `/privacy`, `/accessibility`, the Delete my data page, the access request form, the share dialog, the sensitivity notice, the cookie notice, `llms.txt`, trending retention text | Every one is marked placeholder (`[Placeholder ...]` or `data-placeholder-wording`). The register of files is in `docs/compliance-register.md`. |
| The de-bias term list | The collections team, with Indigenous advisers | `config/debias_terms.yml` (shipped empty) | The mechanism, the import (`bin/rails debias:import CSV=...`), the report (`bin/rails debias:report`) and the explanatory page are built. No terms were invented. See `ead-ccs-test/docs/debias-terms.md`. |
| Cultural-protocols and entity-page notices | Indigenous advisers | Record and entity pages | Placeholder wording. |
| Featured blurbs and Discover wording | The collection teams | `config/featured.yml`, `config/locales/discover.en.yml` | Placeholder. |

## Accepted as they are, with the reason

- **Live share links appear in server logs as paths.** A share token is a secret like a password reset link; keep access to
  logs limited to staff, and use "Stop sharing" or "Make a new link" (both end the old link at once) if a log leaks.
- **Gallery publication for discovery, with moderation (Europeana's publication request) is not built.** A shared list is link-only
  and `noindex`. Moderation needs staff accounts, which wait for login.
- **Subjects with `--` and places like "Town, State, Country" are not split into a tree.** The index values are shown as catalogued;
  a tree needs a data decision from the collections team.

## Earlier decisions

The access tiers (licence-based), the sensitivity placeholder rule, Community Restricted as request-only, the zip limits, the citation
formats and the contact emails are recorded in the handoff note and in their own docs (`docs/adr/`, `ead-ccs-test/docs/`).
