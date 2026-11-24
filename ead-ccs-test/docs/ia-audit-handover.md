# Information architecture fixes: handover (24 Nov 2026)

For the next agent. The audit (below) was done read-only on `design/home-bento`; no IA fix has been made yet. Work through the phases
in order; each phase is one commit (or a few) with tests, pushed to `origin` (`dnbl0/CCS-2027`) on `design/home-bento` or a new
`design/...` branch from it.

## Ground rules (Dean's, non-negotiable)

- Dean (the owner) is not technical: decide for him, report in plain language with a ★ Insight block (Learning output style).
- **New page types need Dean's approval.** Merging pages, moving addresses and renaming menus is restructuring, not a new page type, but
  **ask Dean before Phase 2 (the merged Browse page) and before deleting any public page** (Discover, demo routes).
- Push only to `origin` (`dnbl0/CCS-2027`); never to the Enterprise-Services-Group org repo. Merge only when Dean asks. No `feature/`,
  `bugfix/`, `enhance/` branches. Never read env files; no secrets anywhere. Do not change anything in Jira (reading is fine). No Azure work.
- The DAM token is only in the Keychain (`DAM_API_TOKEN`), read inline, never written. :8984 Solr is read-only.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- CLAUDE.md: check `ListAgents` first; the shared checkout stays on `main`; work in the worktree
  `/Users/nobled/CCS-2027-worktrees/home-bento/ead-ccs-test`.
- Every old address that moves gets a **301 redirect** (bookmarks, search engines, the University's links). Keep WCAG 2.2 AA; site
  tokens only (docs/styling.md).

## Running and testing

- App: http://127.0.0.1:3087 (this worktree, Solr :8985).
- Full suite: `RBENV_VERSION=4.0.6 bin/rails test` (1,664 runs, 0 failures at commit 4244d91).
- System tests: `SOLR_URL=http://127.0.0.1:8985/solr/blacklight-core RBENV_VERSION=4.0.6 bin/rails test test/system/<file>`.
  Known failure, not ours: `colours_test.rb` "Looks similar" (local data lacks those images).
- Do not run system and component tests in one command (they share cached data and give false failures).
- Lint: `bundle exec rubocop <files>`, `bundle exec erb_lint <files>` (with `RBENV_VERSION=4.0.6`).
- Budgets in `test/integration/performance_test.rb` (home 80 kB, 66 preloaded scripts): raise only with a dated note.
- Screenshots: Ferrum scripts in the scratchpad; set cookie `country_acknowledged=1`; on long pages hide other sections
  (`main > section`, not `header`, which also hides section headings).

## Where things live

| Thing | File |
|---|---|
| Routes | `config/routes.rb` |
| Header menus (Search collections, Browse, Help, My saved items) | `app/components/nexus_ccs/header_component.html.erb`, `site_navigation.rb`, `SitePages.menu` (`config/pages.yml`), `BrowseMenu` |
| Footer | `site_footer_component.html.erb`, `SiteNavigation::FOOTER_*` |
| Breadcrumbs (two!) | `PageBreadcrumbsComponent` (Browse, Explore, Help, About) and `BreadcrumbComponent` via `DiscoveryPage#use_meta` (categories, themes, stories, discover, saved, search) |
| Page titles | `content_for :title` in each view; Blacklight's for search and record pages |
| Browse hubs | `BrowseHubs::HUBS` (`app/models/browse_hubs.rb`), `app/views/browse/` |
| Categories | `Categories::DIMENSIONS`, `CategoriesHelper::CATEGORY_LAYOUTS`, `app/views/categories/` |
| Explore pages | `ExploreController` (time, places), `ColoursController`, `app/views/explore/`, `app/views/colours/` |
| Home sections | `ExploreComponent` (`kind_tiles` = classifications, `period_tiles`, `place_tiles`), `pages/home.html.erb` |
| XML sitemap | `Sitemap::STATIC_PATHS`, `Browse::SitemapPaths`, `DiscoverySitemap` |
| Layout guide (keep updated) | `docs/card-layouts.md` |

## The issues (from the audit), by phase

### Phase 1: quick fixes (no structural change; do first)

1. `/collections` redirects to `/#browse-collections`, which no longer exists: point it at `/#explore-title` (the home page's Explore the
   collections section), or at the collections page chosen in Phase 2.
2. XML sitemap: add `/explore/colours`, `/explore/time`, `/explore/places`; drop `/discover` if Phase 4 removes it; leave out themes
   and stories whose title contains "(placeholder)".
3. One page title pattern, "Page — Collections Navigator — University of Melbourne": fix home (hyphen), record pages ("Title -
   Collections Navigator"), Advanced search, search results ("print - Collections Navigator search results": make it "Search results for
   'print' — …"; its h1 says only "Search"), About and Accessibility (missing the middle part). Add a test that checks the pattern on
   every page type.
4. Add Explore by colour to `/browse` (it links to time and place only).

### Phase 2: one Browse (ask Dean first: show him the proposed structure)

5. Merge "Browse the collections" (`/browse`, 5 hubs) and "Browse by category" (`/browse/categories`, 7 dimensions) into one `/browse`
   with sections: Collections, What it is, Where, When, Who (Makers), What it's about (Subjects), Colour, Stories and themes. The
   categories index layouts (`CATEGORY_LAYOUTS`) are the model. Redirect `/browse/categories` to `/browse`; keep or redirect each
   `/browse/categories/:slug` to its hub.
6. Move the Explore pages under Browse so address, menu and breadcrumb agree: `/browse/colours`, and time and place as below; 301 from
   `/explore/*`.
7. "Object types" means two fields: the home section shows `classification_ssim` but its "See all" opens `/browse/object-types`
   (`object_type_ssim`: Work, Archive, Object). Decide (recommend: the home and Browse section "What it is" shows classifications, with
   object type as a filter), then make the home section, its link, the hub and the categories page agree. Fold
   `/browse/categories/object-types` and `/classifications` into it.
8. Time has four pages: `/browse/periods` (centuries, decades, period pages), `/explore/time` (centuries again), `/browse/categories/eras`,
   home Time. Recommend one time page: `/explore/time`'s strip and wall become the `/browse/periods` index; period pages stay; eras become a
   folded list on it (as now on Explore by time); home Time links there. Redirect the rest.
9. Place has four: `/browse/places`, `/explore/places` (map), `/browse/categories/regions`, home Places. Recommend one Places page with
   the map as an opt-in view (it already is opt-in) and regions as its chips; redirect the rest.
10. Collections have four entry points: header menu (5, open search), home listing (36, mostly open collection pages),
    `/browse/categories/collections`, `/browse/collections/:slug`. The menu and every collection link open the collection's own page
    (`HomeCollections.path`); the "Collections" section of Browse lists them; `/browse/categories/collections` redirects there. The 11
    home collections with no records here link to the University's page for them (not a search with no results).

### Phase 3: navigation, labels, breadcrumbs

11. Header menus by task: Search, Browse, Stories and themes, Help, Saved; About under Help (or kept, but one place). The Browse menu
    lists the Phase 2 sections, including Colour, Time and Place.
12. Themes and Stories: in the Browse menu but not under `/browse` and with breadcrumbs "Home › Themes". Make menu, address and
    breadcrumb agree (recommend breadcrumbs Home › Browse › Stories; addresses may stay `/themes`, `/stories`). Their content is
    placeholder: ask Dean whether to hide them from the menu and sitemap until real content exists.
13. One breadcrumb component (keep `PageBreadcrumbsComponent`; move `use_meta` pages onto it). Record pages say "Search results › …"
    whatever the visitor came from; recommend the trail of the page they came from when it is a Browse or collection page (referrer
    within the site), else "Search results".
14. Saving has four names: menu "My saved items", page "Saved records" at `/bookmarks`, bar "0 saved records", plus "Your lists",
    "Saved searches". One word, "Saved": "Saved records", "Saved lists", "Saved searches", menu "Saved".
15. Addresses mix underscores and hyphens (`/saved_searches`, `/search_history`, `/my_data`, `/access_requests`): hyphenated paths with
    301s from the old ones (check Blacklight's own routes for saved searches and search history before renaming; redirect, do not break).
16. Footer: a short "This site" column (Search, Browse, Help, About, Accessibility of this site, Privacy and data on this site, Language
    in our records); keep the University's legal row. Today the footer has "Contact" (University) while this site's contact is under
    Help, and two accessibility and three privacy links side by side.

### Phase 4: orphans and leftovers (ask Dean before removing pages)

17. `/discover` has no inbound links since the home "Featured and trending" section went: link it again (e.g. a Browse section "Pick of
    the day and trending") or remove it with a redirect to `/browse`.
18. Makers and Subjects are linked only from `/browse` (about 3 inbound links each): Phase 2's Browse sections and the menu fix this.
19. Compare is reachable only from a record page: show "Compare (n)" in the Saved menu when it has items.
20. Demo routes `/stock/:id`, `/branded-stock/:id` (two stock records, PR #247/#248): ask Dean whether they stay public; if not, keep them
    out of the sitemap (check) and add `noindex`.

## How to check the result

Rerun the audit's crawl (save as a scratchpad script): fetch the site's own pages, count inbound links per page pattern. After the
fixes every public page has at least 3 inbound links, no page has 0, every redirect lands on a page whose heading matches, every
page's breadcrumb matches its address and menu, and the title test passes. Update `docs/card-layouts.md` and this file (mark each item
done with its commit).
