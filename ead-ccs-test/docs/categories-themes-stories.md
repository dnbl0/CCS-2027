# Categories, collection pages, themes and stories

Added 2026-11-18, with Dean's approval of new page types (recorded in `../../docs/decisions-2027.md`, decision 13). Inspired by the
"explore by category" and curated-story pages of Google Arts & Culture, described in our own words; no code, image or wording is copied
(Europeana code is EUPL: ideas only).

## In plain language

- **Browse by category** (`/browse/categories`): picture pages for seven ways of grouping the records (object type, classification,
  materials, region, era, collection, named collection). Each value is a card with a picture, its name and how many records it has; the
  card opens the search with that value as a filter. Sort by most records or A to Z, 48 cards a page.
- **Collection and named collection pages** (`/browse/collections/...`, `/browse/named-collections/...`): an introduction, highlights with
  pictures, the commonest object types, eras and named collections as links that narrow the search, and "See all N records".
- **Themes** (`/themes`): curated searches from `config/themes.yml`, each a page like a collection page.
- **Stories** (`/stories`): online exhibitions written as Markdown files in `content/stories/`, with record and search embeds, and
  the collection stories (Grainger Museum, Museums Victoria; [collection-stories.md](collection-stories.md)), each read on this site.
  A Markdown story with `draft: true` is not listed, though its address works (the placeholder `example-story.md` is one).
- **Home page**: On this day, Recently viewed and links to Stories, Themes and Browse by category, after the Explore sections.
- **Header**: Browse is now a menu (Browse the collections, Browse by category, Themes, Stories). My saved items links to a short
  explainer of saving, lists and shared galleries on `/lists`.
- **Maker pages** also show born, died, nationality and roles (when the records say so), works with pictures, records by object type and
  related makers (makers sharing this maker's subjects or named collections). See `browse-and-entities.md`.

**Every introduction, theme, story and explainer text is placeholder wording (lorem ipsum or marked "placeholder") until the collections
team approves it.** Files: `config/themes.yml`, `config/collection_intros.yml`, `content/stories/example-story.md`,
`config/locales/categories_themes_stories.en.yml`.

## Rules every page follows

- Every list of records opens Blacklight's own search page (`/catalog` with facet filters, `any_assets=1`): nothing re-implements search.
- A picture is shown only when a result card would show it: `AccessPolicy.view?` and not `Sensitivity.sensitive?`; highlights and story
  search strips also leave out withheld records (`Discovery.listable?`). `thumbnail_path_ssi` may be a DAM address or a local file.
- The Indigenous Collections card has no picture (`ExploreEntryPoints.text_only?`), as on the home page.
- Cards are the site's own components: `CardSectionComponent` + `CardLayoutComponent` (`grid`) for category cards, `RecordCardComponent`
  / `RecordCardsComponent` for records. A category card's label carries its count, so a narrow card that drops its description still shows it.
- Fields the index may not have (`region_ssim`, `date_era_ssim`, `nationality_ssim`) give an empty category page or no fact, not an error.

## How it is built

| Part | Code | Solr |
|---|---|---|
| Category pages | `Categories`, `CategoriesController` | One request a dimension: the facet over every record (`{!ex=img}`) and the first 1,000 records with a thumbnail for the pictures. Cached a day, last good copy a month |
| Collection pages | `CollectionLandingsController`, `Showcase` | One request (highlights, facets, total); cached 6 hours. The address is a `Browse::Slug` of the value; an unknown one is a 404, a stale readable part a 301 |
| Themes | `Themes`, `ThemesController`, `Showcase` | As collection pages; a `hero` record adds one lookup. `Themes.problems` checks the file (a test runs it) |
| Stories | `Stories`, `StoriesController` | One lookup for every embedded record, one search per search embed (the catalog's own search builder); cached an hour. With Solr down the text still shows |
| On this day | `OnThisDay`, `pages/_home_on_this_day` | Day and month in the forms the records use ("18 November 1923", "1923-11-18"), else this year 50, 100, 150 or 200 years ago. Cached for the day; a failure for 5 minutes |
| Recently viewed | `RecentlyViewed`, `pages/_home_recently_viewed` | Only when the visitor has opened records |
| Maker facts | `Browse::Creator`, `browse_entities/_creator` | Facts read from the page's records naming the maker alone; related makers one facet request, cached 6 hours |

### Story syntax

Front matter: `title`, `summary`, `hero` (a record id), `author`, `date`. Embeds, each alone on a line:

```
{{record emu_mc-20882}}
{{search "violin"}}
{{search "q=violin&f[collection_ssim][]=Grainger Museum Collection" "Violins in the collection"}}
```

The Markdown is converted with kramdown and sanitised (paragraphs, headings h2 to h4, lists, links with `href` only, emphasis, quotes,
code); scripts, styles, images and event attributes are removed. A search embed keeps only `q`, `f`, `range` and `search_field`.

**Spotlight is not used**: it needs staff sign-in, which this site does not have (decision 13).

## Search engines

The pages are indexable with a canonical address (`Browse::Meta`, `PageMeta`); category page 2 on, and collection pages under 5 records,
are `noindex, follow`. The sitemap (`DiscoverySitemap`) lists every category page, theme and story, and collection pages with 5 or more
records.

## Tests

`test/models/discovery_content_test.rb`, `test/integration/discovery_pages_test.rb`, `test/system/discovery_pages_test.rb` (axe WCAG 2.2 AA
and no sideways scroll at 1440 and 390px; the count visible at 320px).
