# Collections are filtered results, and URLs stay Blacklight's

**Status: amended (17 Nov 2026).** Decision 13 in `docs/decisions-2027.md` approved collection and named-collection pages
(`/browse/:kind/:slug`, `CollectionLandingsController`), category pages, themes and stories as an exception. Their records are
still opened as filtered results in `/catalog`, as below.

A collection has no landing page: it is `/catalog?f[collection_ssim][]=<name>`. The five collection landing pages were removed on
2026-10-16 and `/collections/<slug>` redirects to the filtered results; `/collections` redirects to the home page's collection
cards. The site keeps Blacklight's own URLs (`/catalog`, `/catalog/:id`, `/catalog/advanced`, `/search_history`) rather than
inventing its own, so the gem's links, tests and documentation keep working.
