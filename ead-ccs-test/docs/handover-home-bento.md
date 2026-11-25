# Handover: design/home-bento (25 Nov 2026)

For the next agent. Read this first, then `docs/ia-audit-handover.md` (the IA fixes, all done) and `docs/card-layouts.md` (every layout).

## Where things are

- Branch `design/home-bento`, worktree `/Users/nobled/CCS-2027-worktrees/home-bento/ead-ccs-test`, pushed to `origin`
  (`dnbl0/CCS-2027`). Last commit `ed82eab`. **Nothing is merged; merge only when Dean asks.** No PR is open for this branch.
- App: http://127.0.0.1:3087 (this worktree, Solr :8985). PR #90's record page work runs on :3085 (another worktree).
- Full suite: `RBENV_VERSION=4.0.6 bin/rails test` → 1,664 runs, 0 failures.
- System tests: `SOLR_URL=http://127.0.0.1:8985/solr/blacklight-core RBENV_VERSION=4.0.6 bin/rails test test/system/<file>`.
  Known failures that predate this branch (local index lacks their records): `access_request_test.rb`, `responsive_test.rb` record and
  access-form checks, `colours_test.rb` "Looks similar". Never run system and component tests in one command (shared cache, false failures).
- Lint changed files: `RBENV_VERSION=4.0.6 bundle exec rubocop <files>`, `bundle exec erb_lint <files>` (in zsh split lists with `${=VAR}`).
- Budgets (`test/integration/performance_test.rb`): home HTML 88 kB, 66 preloaded scripts. Raise only with a dated note.

## Dean's rules (non-negotiable)

Dean is not technical: decide for him, report in plain language with a ★ Insight block (Learning output style). Push only to `origin`,
never the Enterprise-Services-Group org repo. Merge only when asked. No `feature/`, `bugfix/`, `enhance/` branches. Never read env files;
no secrets in files, PRs or messages; the DAM token lives only in the Keychain (`DAM_API_TOKEN`), read inline. :8984 Solr read-only. Do
not change anything in Jira. No Azure work. Keep CCS 2026 and 2027 separate. New page types need Dean's approval. Never cut First
Nations works into puzzle pieces (Look closer). CLAUDE.md: `ListAgents` first, announce your area, shared checkout stays on `main`.
Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with
`🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## What this branch did (newest first)

| Commit | What |
|---|---|
| ed82eab | Home Time section: the National Gallery of Art's "Now on view" card carousel (`CardCarouselComponent`); no longer a navy band |
| 9a239df | Home collections with no records here open their University page (`url:` in `config/home_collections.yml`) with a note |
| 5c6ef48 | IA fixes (20 items): one Browse at `/browse`; `/browse/time`, `/browse/places`, `/browse/colours`; category pages `/browse/<name>`; 301s from every old address; one breadcrumb (`PageBreadcrumbsComponent`); one title pattern; "Saved" menu; footer columns; hyphenated addresses |
| 4244d91 | Pictures load gracefully sitewide (`page_loader.js` + `components/image_reveal.css`); Explore by colour cards and wall neighbours |
| 2edc304 | Browse sections on the home page's layouts (`CategoriesHelper`) |
| ee7e07f | Home: `ClusterComponent` (On this day), `FeatureCarouselComponent` |
| f3e12d9 | Explore by time: century strip and picture wall (`PictureWall`, `explore_strip_controller.js`) |
| b9ab139, aa55852 | Explore by colour after Google's Color Explorer; Google Arts & Culture home sections (stacks, Look closer) |

## The layout system (reuse these; `docs/card-layouts.md` has the details)

`StackComponent` (fan, or `captions: false`), `ClusterComponent` (3–4 cards), `FeatureCarouselComponent` (story slides, Browse's eras),
`CardCarouselComponent` (NGA cards, home Time), `LookCloserComponent`, `MosaicComponent` (whole pictures), `SimpleListingComponent`,
`explore/_picture_wall`. Every section is a `HomeSectionComponent` (`tint:` for a colour band). Tiles are `HomeSections::Tile`.
Carousels share `carousel_controller.js` (no new script needed).

## Gotchas learned

- Ferrum screenshots: set cookie `country_acknowledged=1`; long pages time out, so hide other sections (`main > *`), never `header`
  (it hides section headings); Chrome's minimum window is 500px wide. Pictures need ~6 s to load before a shot.
- Claude in Chrome blocks tool output containing links with query strings: return measurements, not raw HTML.
- Route names: a redirect route takes the helper name unless given `as:` (the IA fix gave old addresses `legacy_*`).
- `/browse/places` is the map page; with `view`, `letter`, `filter`, `page` or `region` in the query it is the old Places A–Z hub.
- Locale overrides of Blacklight keys may live in `search_bar.en.yml` as well as `blacklight.en.yml` (check both).

## Open, for Dean to decide or for later

- Themes and stories still carry "(placeholder)" wording; they are out of the sitemap, still in the menu.
- Blacklight's own `DELETE /search_history/clear` keeps its underscored address (engine route).
- Look closer can occasionally show the same record as a Time card on the same day.
- MONIAC Economics Model Machine has no University page; it opens the search.
- When Dean asks to merge: open a PR from `design/home-bento` to `main` on `origin`, body ending with the line above, list the commits.
