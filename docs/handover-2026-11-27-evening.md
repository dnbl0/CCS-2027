# Handover, 27 Nov 2026 evening (resume here)

For the next Claude agent. Read this first, then `docs/handover-2026-11-27.md` (the owner, his standing rules and the working
method, all still in force), `CLAUDE.md`, `CONTRIBUTING.md` and `docs/audit-2026-11-27.md`. Where they disagree, this file wins.

## The owner, in one paragraph

Dean Noble is **not technical**. Decide for him, carry the work through, and report in plain words: what changed, what he can
see, what needs him. Ask only for decisions that are really his, and explain each one without jargon. (He did not understand
the "routes not covered by a decision" question; it is re-worded below.) Standing rules, unchanged: no record counts outside
search results; never crop pictures of objects; CCS 2026 and 2027 stay separate; no Azure or hosting work without his
go-ahead; never push to the `org` remote; never edit Jira; no secrets anywhere.

## What Dean decided on 27 Nov

1. **#91 approved** (Grainger Museum stories on record pages). Merged.
2. **Show the Museums Victoria stories about University objects.** Done in #93 (merged). The data holds **19** such stories,
   not 22 as the earlier notes said.
3. **Remove the trial record pages** `/stock` and `/branded-stock`: #107.
4. **Remove the 2026 static prototype** from the repository: #108. Both are recorded as decision 16 in `docs/decisions-2027.md`
   (added by #107).
5. **New, still in progress:** a stories index like https://www.britishmuseum.org/blog, and **a story must open on Collections
   Navigator, not on the website that first published it**: draft #109 (below).

## Pull requests

| PR | What | State at handover | Next action |
|---|---|---|---|
| #96 | No counts outside search results | Merged | |
| #91 | Grainger stories on record pages | Merged | |
| #93 | Museums Victoria: 39 story records and 41 objects (Engineering and IT Collection); `config/collection_stories_museums_victoria.yml` puts each story on its objects' pages | Merged | After merging, run `bin/rails collections:index_harvested` against any Solr core you test with |
| #104 | UI text into locale files (audit T6); `script/i18n_check.rb` checks every app namespace | Merged | |
| #105 | System tests wait for a condition, not `sleep` (T15): `wait_until`, `wait_for_animations`, `wait_for_settled_page`, `wait_until_stable` in `ApplicationSystemTestCase` | Merged | |
| #106 | CSS T8: `film_polish.css` and `card_tiles.css` folded into their components; 30 screenshots pixel-identical | Green, **behind main** | Merge `origin/main` in, push, wait for `rails` and `system`, merge |
| #107 | Remove `/stock`, `/branded-stock` (old addresses 301 to `/catalog/:id`); ADR 0006 superseded; decision 16 | Main merged in (conflict in `accessibility_test.rb` resolved: the stock block is deleted); CI running on 563ffc9 | Merge when green on its latest commit |
| #108 | Remove the 2026 prototype (`public/`, `src/`, `tests/`, prototype `scripts/`, `api/`, `ci.yml`, ESLint); root `package.json` keeps only axe-core and stylelint; the `system` job now runs `npm run lint:rails-css` | Green, behind main | Merge **after #107** (its README cites decision 16). Merge main in first |
| #109 (draft) | Stories read on this site; `/stories` after the British Museum's blog | Work in progress | See next section |

Merge procedure (unchanged): merge `origin/main` into the branch, push, wait until `rails` and `system` pass **on the latest
commit**, then `gh pr merge N --repo dnbl0/CCS-2027 --merge`. Each merge into main makes the other open branches stale, so
merge one at a time. The `system` job is slow on a new branch (10-25 min): its Solr download from archive.apache.org is not
cached across branches. A faster mirror and a curl timeout would help (not done).

## #109, stories on this site (the open feature)

Branch `feature/stories-in-site`, worktree `~/CCS-2027-worktrees/stories-in-site`.

**Done (committed as WIP, tests pass):**
- `CollectionStories::Story` has `slug`, `path` (`/stories/<slug>`), `date` (Grainger: the month in its address), `body`,
  `author`, `image_alt`, `image_caption`, `image_credit`, `licence`, `licence_url`, `record_ids`; `CollectionStories#stories`.
- `Stories.all` and `Stories.find` include every collection story (`Stories.from_collection`). `Stories::Story` gained
  `category`, `image`, `source` (`full_text` false for Grainger), `records`, `html`, `draft`. Newest first; undated
  (Museums Victoria) after, by title. The placeholder `content/stories/example-story.md` is `draft: true`: not listed, but its
  address works.
- `scripts/museums-victoria/build_harvested_rows.py` writes each Museums Victoria story's full text (HTML, sanitised on the
  page), author, picture caption and credit, CC BY licence, slug and record ids. Links inside the text to a story or object the
  site holds point to the site's own page.
- Record-page story cards (`CollectionStoryComponent`) link to `/stories/<slug>`.
- `/stories`: `NexusCcs::StoryCardComponent` ("category / date", headline link stretched over the card, summary, "Read more"
  hidden from screen readers), the first story `lead`. `StoriesController#pictured_records` fetches each card's fallback record.
  `story_image_controller.js` takes a `textClass` value.
- `/stories/<slug>`: category · author · date; the story's picture with caption and credit (falls back to the record's picture);
  for Grainger, the summary and "Read the full story on the Grainger Museum website"; an "About this story" note crediting the
  source and its licence; "Objects in this story" as record cards.
- Tests: `test/models/stories_from_collections_test.rb`, `test/integration/stories_pages_test.rb`, updated
  `collection_stories_component_test.rb`, `record_collection_stories_test.rb`, `discovery_pages_test.rb`.

**Left to do, in order:**
1. **Stylesheet.** No CSS exists yet for `.stories-index`, `.story-card*`, `.story-page__figure`, `__caption`, `__source`.
   Add `app/assets/stylesheets/components/stories_index.css` and import it in `application.css`. The British Museum layout:
   lead story full width (picture left, text right from 1024 px; stacked below), then a 3-column grid (2 at 600 px, 1 on
   phones); 16:9 picture box with `object-fit: contain` on a neutral ground (**never crop**); kicker small caps-style line;
   serif headline; the `.story-card__link::after` stretched over the card; focus ring on the card (`:has(:focus-visible)`), as
   `collection_stories.css` does. `.story-card--text` = no picture. Use `--ccs-*` tokens only.
2. Run the app, look at `/stories`, `/stories/csirac-collection`, `/stories/bridgeport-presentation-baton` and a record with a
   story (`/catalog/harvested-items_1686199`, `/catalog/emu_mc-400253`) at 1440 and 390 px. Put screenshots for Dean in
   `~/Desktop/CCS stories screenshots/Version 4 - stories on the site/`.
3. Add a system test with axe for `/stories` and one story page (`assert_accessible tags: AXE_TAGS + WCAG22_TAGS`).
4. Docs: `ead-ccs-test/docs/collection-stories.md` and `docs/categories-themes-stories.md` (stories now include collection
   stories; `draft:`; the Grainger text limitation). Record the owner's request as a row in `docs/decisions-2027.md`.
5. Full checks, mark the PR ready, merge when green, then tell Dean in plain words.

**Known limits to tell Dean:** the Grainger Museum's site still refuses automated reading (checked once on 27 Nov: 403), so
its stories show their summary plus a link to the full text there; **do not work around the block**. If the University web
team allows the harvester, add `body` to `config/collection_stories.yml` entries and the pages show the full text with no
other change. Museums Victoria gives no publication dates, so those stories are listed after the dated Grainger ones.

## After #109: the rest of the original plan

1. **CSS T7**: about 15 hard-coded colours and font sizes in `record_classic.css` and `results_toolbar.css` have exact matches in
   the palette tokens (`--palette-grey-10` #1a1a1a, `--palette-cyan-94-2` #e3f4fb, `--palette-navy-14-2` #1b1f2a,
   `--palette-navy-27-2` #3b4050, `--palette-stone-93` #f1efea, `--palette-navy-23` #0b2a6b, `--palette-stone-91` #ece9e3,
   `--ccs-font-size-ui` 0.9375rem, `--ccs-font-size-2xs` 0.8125rem). The colour swatches in `colours.css` are content: keep them.
   Do it after #106 merges.
2. **CSS T9**: one card shell for result, explore, story and record cards; one breadcrumb.
3. Prove "no visual change" the same way as #106: a server on main and one on the branch (each with
   `SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core`), headless Chrome screenshots of 15 pages at 1440 and 390 px, then
   `compare -metric AE before.png after.png null:` (ImageMagick). Take the baseline twice first to prove there is no noise. In
   zsh never name a variable `path` (it is tied to `PATH`).

## Questions waiting for Dean (asked on 27 Nov, not yet answered)

1. **Security before launch (audit T5).** Recommended: yes to the parts inside the code (stop shipping `solr/security.json`
   in the image, pin GitHub Actions to commit SHAs, enforce the browser security policy with a report address); wait on the
   hosting parts (database firewall, OIDC instead of registry passwords) until hosting is decided. Do nothing until he says yes.
2. **Six pages with no recorded decision.** In plain words: Compare (images side by side), Selection (tick several results to
   download or save together), a record's metadata download, the bulk download review step, "Language in our records", and
   About. Recommended: keep all six and record that as a decision. Ask again in these words if he has not answered.
3. Still open from before: the email asking the University web team to let the stories harvester through.

## Working notes

- Work in a worktree under `~/CCS-2027-worktrees/`, never in `~/CCS-2027` (it is on an old `main` with Dean's uncommitted files).
- **Local Solr data differs from CI's**: about 20 system tests fail locally on unchanged `main` (media viewer, debias,
  saved searches, home explore, browse sections). Before blaming a change, run the same tests in a detached worktree of
  `origin/main` (`git worktree add --detach ../CCS-2027-worktrees/baseline origin/main`, then remove it).
- Timing-sensitive tests (colour extractor, health, debias performance) can fail when the laptop is busy: rerun alone.
- The Museums Victoria source data (`unimelb_related_stories.json`, 4 MB, not committed) is in
  `~/Desktop/CCS stories screenshots/Museums Victoria stories/`. Re-run the builder with `--items-cache` so it does not call
  the API; the API rate-limits (429) and the script stops rather than retrying. Do not work around it.
- Check `ListAgents` before starting (CLAUDE.md rule 1). On 27 Nov no other session was working on CCS-2027.
