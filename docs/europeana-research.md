# Europeana and Google Arts & Culture: what CCS 2027 can learn

Research for the CCS 2027 site (Rails 8, Blacklight 9, Solr 10). Written 3 November 2026. Companion file: [europeana-research-sources.md](europeana-research-sources.md), which lists every repository and file read, with its address and what it taught.

## Read this first: licence and use of this document

Europeana publishes its code at github.com/europeana, mostly under the European Union Public Licence 1.2 (EUPL-1.2, a "copyleft" licence). This document is a **design-ideas reference**. It describes behaviour and design in our own words and links to the source files. It contains no Europeana code, configuration or long text, and nobody should paste any into CCS. Copying or closely adapting Europeana code would bring EUPL conditions (for example, sharing the combined work under the same licence) and needs the University's licensing view first. Ideas, data formats and open standards (IIIF, W3C Web Annotation, RightsStatements.org, Creative Commons, Solr) are free to use; the Europeana *licensing framework* repository is CC0.

Google Arts & Culture is closed source. Section 6 only describes what its public pages and Google's blog show. europeana.eu itself refuses automated requests (HTTP 403), so everything here comes from GitHub (source code and READMEs).

## 1. Plain-language summary

**What Europeana is.** A search site over about 60 million records from European museums, libraries and archives. It does not hold the records itself; it indexes descriptions supplied by institutions, plus a small thumbnail of each image.

**What we found.** Europeana's strength is not clever search. Its Solr setup is plainer than ours (no stemming, simple relevance). Its strength is *product design around the search*:

1. **Everything is a filter.** People, places, topics and "collections" are pages that are simply a saved search (the page shows the entity's description, then runs a search restricted to it). We can do the same from the Solr facets we already have.
2. **Rights drive the experience.** Every record carries a rights statement; those are grouped into three plain classes ("open", "restricted", "needs permission"), and a filter and an embed button follow from the class. Our `AccessPolicy` already does the same thing in spirit, so this is mostly a matter of exposing it as a "free to reuse" switch and standard rights links.
3. **Simple "similar items".** For logged-out visitors it is just a boosted search: other records sharing subject, creator, or provider, with the record itself excluded. No machine learning is needed to start.
4. **Trending** is a weighted count of views, downloads, likes and "added to gallery" in the last day, compared with the day before. It lives in a small Postgres table.
5. **Galleries (sets)** have three states: private, public (anyone with the link), and published (reviewed by staff and listed). Asking for publication creates a staff ticket. That is the moderation model.
6. **De-bias notices** are underlined terms in record text with a pop-up explanation and a page per term. The terms come from a reviewed vocabulary and are attached to records as W3C annotations.
7. **Colour search** uses a fixed palette of 138 named colours; each image is reduced to its dominant colours when it is ingested, and the colours are stored as small numeric codes.
8. **Multilingual search** translates the visitor's query and the record text using a translation service, and is limited to logged-in users (to control cost).

**What we have that Europeana does not, or does better.** ICU-folded analysers with synonyms and stemming; phrase boosting; highlighting ("matched in"); Indigenous cultural and intellectual property (ICIP) handling in `AccessPolicy`; a sensitivity gate. Europeana has no equivalent of a per-visitor sensitivity prompt.

**Honest data limits for us.** The index has 40,962 records, but only 137 have a digital asset, 76% (31,111) have no licence value, and our creators, subjects and places are text labels with no authority identifiers (no Wikidata/ULAN links). Colour search, visual similarity, maps and full-text search all depend on data we mostly do not have yet. The roadmap in section 7 is ordered with that in mind.

## 2. Our stack and data (the baseline for every comparison)

Read from `docs/architecture.md`, `ead-ccs-test/config/data_model/solr_mapping.yml`, `ead-ccs-test/solr/conf`, `catalog_config/facets.rb`, `iiif_manifest.rb`, `access_policy.rb`, `search_highlighting.rb`, and measured read-only against the shared Solr (`blacklight-core`, Solr 10.0.0 / Lucene 10.3.2).

| Fact | Value |
|---|---|
| Records | 40,962 (University Art Collection 16,340; Grainger 13,408; Medical History Museum 7,719; Dental Museum 2,572; Anatomy and Pathology 920; University of Melbourne 3) |
| With a digital asset (`has_digital_asset_bsi`) | 137 (62 are public domain, 7 current copyright, 5 reproduction licence; 74 have any licence value) |
| Media (audio/video) | 3 records (`digital_media_ssim`) |
| Licence value present (`licence_type_ssim`) | 9,851; blank 31,111 |
| Creator (`creator_ssim`) | 31,594 records; 7,821 distinct names; includes "Unknown" (1,400) and "Unknown (posters)" (1,309) |
| Subject (`subject_ssim`) | 15,894 records; 1,601 distinct values; some are cataloguing tags ("Exhibition", "DOCUMENTS--Letters") |
| Place (`production_place_ssim`) | 13,355 records; 1,018 distinct values, mixing continents, countries and cities |
| Dates | `date_start_isi` on 28,264 records; creator birth year on 17,930 |
| Description | 10,659 records (so free text is thin) |
| Parent/child | `parent_record_ssi` on 7,903; related objects on 641 |
| Coordinates, colours, vectors, full text | none in the index |
| Search config | edismax; title^5, alt title^3, creator^3, subject^2, description, catch-all text; phrase boosts (pf, pf3); `mm` set per request in `SearchBuilder`; ICU tokenizer, folding, synonyms, stemmed catch-all field; spell-check and suggester fields exist |
| Facets | 23 workbook filters; `InclusiveFilterField` for multi-select OR; range limit for years; digital asset on/off |
| IIIF | `IiifManifest` builds Presentation 3.0 manifests for records with images; viewer is OpenSeadragon |
| Rights | `AccessPolicy` gives three tiers (open, view_only, request) from `licence_type_ssim`; `Sensitivity` adds a visitor prompt |
| Visitors | no login; a session-keyed guest row in Postgres holds lists, saved searches, history, access requests |

Consequences that recur below:

- Without logins we cannot copy Europeana's account features directly (likes, private sets, API keys, multilingual-for-members). A guest-key model (already used for lists) covers private galleries; "publish" needs a staff-only admin.
- With 137 assets, anything that needs images (colour, visual similarity, annotations on images, IIIF-heavy features) will look empty until the DAM feed (`assets_json`) arrives. Build the plumbing, but do not promise the visitor-facing result yet.

## 3. Europeana's portal (portal.js): what each feature does and how it maps

Repository: [europeana/portal.js](https://github.com/europeana/portal.js) (EUPL-1.2, a Nuxt/Vue monorepo; `packages/portal` is the site). Almost all data comes from Europeana's own APIs, so the front end is thin; the ideas live in how it asks questions.

### 3.1 Search, the query builder and filters

**How it works.**
- The *advanced search* page is a list of rules. Each rule is a field, a modifier ("contains", "does not contain", and "exact" for full-text) and a term. Submitting turns each rule into one Lucene-style clause and puts the clauses into a repeated URL parameter `qa`; the page reads the same parameter back into rules, so a search is a shareable link and the form is rebuilt from the link. Terms are escaped for Lucene special characters. Source: [mixins/advancedSearch.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/mixins/advancedSearch.js), [SearchQueryBuilder.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/search/SearchQueryBuilder.vue).
- Fields have a *type* (text, string, full text) which decides which modifiers are legal. Some fields are tied to an entity type, so typing in "creator" offers suggestions of people (the "suggest" call of the Entity API), and picking one fills in the canonical name. Four *aggregate* fields (who, what, when, where) search several underlying fields at once.
- Validation is simple: if any of the three controls in a rule has a value, all are required; empty rules are ignored.
- *Filters* (type, reusability, content tier, country, language, provider, colour, image size, orientation, MIME type, rights) are facet dropdowns. Selections become `qf` parameters of the form `FIELD:value`. Two filters are special and travel in their own parameters, not `qf`: **reusability** and **sort**. Changing the "collection" (theme) clears collection-specific filters. See [SearchFilters.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/search/SearchFilters.vue).
- *Switch filter*: a checkbox-style toggle with a "checked" value, an "unchecked" value and a default. When the control is at its default, the parameter is dropped from the URL (so a default search has a clean URL). The one switch in use is "include items without media" ([SearchSwitchFilter.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/search/SearchSwitchFilter.vue)).
- *Default quality gate*: unless told otherwise, searches only return records of content tier 1 to 4 (tier 0 means no usable media); within a themed collection tier 1 is also dropped; organisation pages show all tiers ([plugins/europeana/search.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/plugins/europeana/search.js)). This is the same idea as our ADR 0004 (results default to records with a digital asset).
- *Date filter* appears only for themes whose records have a usable date (newspapers); it is a from/to range turned into one range clause. Our range-limit plugin already does this for years.
- *Query options* (the search box dropdown): as you type, the box offers entity suggestions, a "search in this collection" option and recent searches ([SearchQueryOptions.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/search/SearchQueryOptions.vue)).
- Pagination is capped at 1,000 results (deep paging is blocked), 24 per page.

**Reusable idea.** Rule rows that serialise to one URL parameter per rule and parse back; field-type-aware modifiers; a switch filter that disappears from the URL at its default; a documented, capped result window.

**Mapping to us.** Blacklight's advanced search already accepts several clauses; our `QuerySyntax` and `SearchBuilder` (`mm` per request) already know whether a query is Boolean. A rule builder is a front-end (Stimulus + ViewComponent) job that writes the same clause parameters Blacklight reads, plus a small mapping from rule to Solr clause using our fields (`title_tsim`, `creator_tsim`, `subject_tsim`, `description_tsim`, string `_ssim` fields for exact). Modifiers: contains (edismax on the text field), exact (quoted phrase, or `_ssim` string match), does not contain (negated clause). Suggestions for creator/subject/place can come from a Solr facet prefix query or the suggester, no entity API needed.

**Gaps.** No entity identifiers behind names; no per-field language. Blacklight's built-in advanced form uses its own widgets and our `AdvancedYearRangeComponent`; a rule builder replaces or sits beside it, so keep one canonical URL form to avoid two competing parameter schemes.

**Recommended approach.** Keep Blacklight's `clause[n][field|query]` parameters as the canonical form, render rules from them, and add an "is free to reuse" switch built on the existing `DigitalAssetFilterField` pattern (Section 7 item D). Test that a copied link rebuilds the same rules.

### 3.2 Entity pages (people, places, topics, times, organisations)

**How a page is assembled** ([pages/collections/_type/_.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/pages/collections/_type/_.vue)):
1. The URL has a type (`person`, `topic`, `place`, `time`, `organisation`) and an identifier, with an optional readable name after the number. The page redirects to the preferred path so the name in the URL is canonical.
2. It fetches the entity record (preferred label in many languages, description or note, image, homepage, and for organisations an address and logo) from the Entity API ([plugins/europeana/entity.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/plugins/europeana/entity.js)).
3. It runs the ordinary search interface with the filter "this record is linked to entity X". The same search results page, sidebar facets and sort are reused. The query string is also set to the entity filter so that editors' "best bets" (curated items) rise to the top.
4. A **related collections** card shows up to four other topics that most often co-occur with this one: it runs a zero-row search, asks for the facet counts of the *topic* field, and keeps the top four that are Europeana entities and not the page itself ([EntityRelatedCollectionsCard.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/entity/EntityRelatedCollectionsCard.vue)).
5. **Editorial** content (stories, galleries) linked to that entity in the CMS appears alongside.
6. Editors with a role can pin a hand-picked "best items" set for an entity.
7. **Browse by type** lists entities, 24 a page, sorted by label in the visitor's language ([EntityTypeBrowse.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/entity/EntityTypeBrowse.vue)). For organisations there is a sortable, searchable table (name, country, aggregator, domain, number of items) with expandable rows ([EntityTable.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/entity/EntityTable.vue)) and a map of organisations.
8. On a record page, linked entities show as badges and clicking one goes to the entity page.

**Mapping to us.** Our "entities" are facet values: creators (`creator_ssim`), subjects, places, object types, materials, collections. A hub can be made with no new service:
- URL: `/browse/creators`, `/browse/creators/<slug>`; slug derived from the value (with a stable fallback to the exact string via a lookup).
- Page header: name, birth/death from `creator_display_ssim`/`creator_birth_ssi`, record count from a facet query; description only where we have one (we have none today; allow an optional YAML or Markdown profile per entity, Section 7 item K).
- Body: the existing results view with `fq=creator_ssim:"..."`.
- Related: a facet query on `subject_ssim` (or `creator_ssim`) within the entity's results, top four, excluding itself; this is the same technique and works with our data.
- Browse index: alphabet index, count, sorted table. Facet queries with `facet.limit=-1` on 7,821 creators are fine for Solr but should be cached and paged.

**Gaps.** No identifiers, so no cross-collection joining ("Percy Grainger" vs variants), and no multilingual labels. 1,400 "Unknown" creators need hiding from hubs. Deduplicating name variants is a data-owner task. Places are a mix of levels, so a place hub will be uneven until a place hierarchy exists. Indigenous creators and communities need review before being made into public "pages" (protocol risk, Section 7).

**Recommended approach.** Build hubs as search presets over facets; give each hub a stable slug table in the database or a YAML file so URLs survive renames; add optional hand-written descriptions later.

### 3.3 Item recommendations and trending

**Similar items.**
- Logged-out visitors: a *lexical* query built from the current record: its subjects and type (weight 0.8), its creator (0.5), its data provider (0.2), as quoted alternatives, minus the record itself; four results; tier filter applied; "minimal" response profile ([mixins/similarItems.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/mixins/similarItems.js), [ItemRecommendations.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemRecommendations.vue)).
- Logged-in visitors: a separate Recommendation API returns up to eight. The portal removes the record itself from the answer and logs which algorithm produced each click, with rank, so the two can be compared ([plugins/europeana/recommendation.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/plugins/europeana/recommendation.js)).
- That engine (separate repos) embeds the record's text with a multilingual language model, shrinks it to 300 numbers, stores the vectors in a vector database (Milvus) and finds nearest neighbours by distance; an updater batch job processes records from the main index ([recommendation-api](https://github.com/europeana/recommendation-api), [recommendations-updater](https://github.com/europeana/recommendations-updater), [embedding-api](https://github.com/europeana/embedding-api)). It works on *metadata text*, not on images.

**Trending.**
- A page and a block that show the most "trending" records. Behaviour logged by the site (views, downloads, likes, additions to a set) is stored as events in Postgres. The score of a record over the last 24 hours uses weights (view 1, download 2, like 4, add-to-set 6), compared with the 24 hours before, so records rising fast beat records that are merely always popular. The portal then fetches those records by identifier and keeps the ranking order ([ItemTrendingItems.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemTrendingItems.vue), [server-middleware/api/events/trending.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/server-middleware/api/events/trending.js)).
- For development, a "mock" mode shows a day-seeded random set instead.

**Mapping to us.**
- *Similar items now:* a Solr query using the same recipe with our fields: `subject_ssim` and `object_type_ssim` weight 0.8, `creator_ssim` 0.5, `collection_ssim` or `named_collection_ssim` 0.2, minus the record id, plus a "has digital asset" bias. Solr's built-in More-Like-This handler is an alternative on `title_tsim`, `subject_tsim`, `description_tsim`, but descriptions are present on only 26% of records, so facet-field matching will behave better than text similarity. Put the recipe in one model (`SimilarRecords`) with a test that the record itself is excluded and results are stable.
- *Visual/semantic similarity later:* Solr 10 supports dense vector fields and k-nearest-neighbour queries natively, so no separate vector database is needed. Text-embedding similarity could cover all 40,962 records, but needs an embedding model and a rebuild job (Section 7 item G).
- *Trending:* we already record searches and saved items in Postgres without logins. A small `record_events` table (record id, kind, session day) with the same weights and a nightly roll-up would work. Privacy: store the record id, kind and day only, not the session; do not expose raw counts for ICIP-flagged or withheld records. With low traffic, "trending" will be noisy; combine with an editorial "featured" list so the block is never empty. Bots: count only events that pass `BotGuard`.

**Gaps and risks.** Trending can amplify sensitive material (human remains, ICIP): exclude `:request` tier records and anything flagged by `Sensitivity`. Counting events is analytics under the University's privacy policy; check before launch.

### 3.4 Sets (galleries): creation, visibility, publication

**Model** ([plugins/europeana/set.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/plugins/europeana/set.js), [UserSets.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/user/UserSets.vue)):
- A *set* has a title, description, creator, ordered items and a **visibility**: `private` (only the owner), `public` (anyone with the link, not listed), `published` (listed on the public galleries page). Types include ordinary collections ("Collection"), a special private "likes" folder (BookmarkFolder), and an editor-curated "best items" set that is attached to an entity page.
- Items can be inserted at a position, removed, repositioned, or *pinned* to the top. An item can be searched within a set.
- **Publication request.** The owner of a public set asks for publication; the portal posts a ticket (page link, title, description, creator nickname, requester email) to a service-desk integration ([SetPublicationRequestWidget.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/set/SetPublicationRequestWidget.vue)). Staff holding the "publisher" role then press publish or unpublish ([SetPublishButton.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/set/SetPublishButton.vue)); the button first re-reads the set, and if its visibility changed in the meantime it warns instead of overwriting. Owners cannot publish themselves.
- **What moderation means here.** Moderation is *editorial gatekeeping of what is featured*, not pre-approval of every set: private and public sets are not reviewed; only publication needs a human, on request. Separately, Europeana's Annotation API has a moderation record per annotation with endorse and report votes, so inappropriate user tags can be flagged ([ModerationRecord.java](https://github.com/europeana/annotation/blob/master/annotation-definitions/src/main/java/eu/europeana/annotation/definitions/model/moderation/ModerationRecord.java)).
- Older "galleries" were editorial pages in the CMS and were migrated into sets, which is why both words appear.

**Mapping to us.** Our `List`/`ListItem` (guest-owned, ordered) is the base. Add: `title`, `description`, `visibility` (private/link/published), a random unguessable share token, `published_at`, `reviewed_by`. A guest key is not an identity: treat "link" sets as unlisted, rate-limit creation, and require a nickname or email only for the publication request. Staff review can start as a CSV or admin page in the same style as `access_requests:export`; no email is needed. Items must carry only record ids; at render time apply `AccessPolicy` and `Sensitivity` so a shared gallery never shows an asset the visitor may not see.

**Risks.** User-written text on a public page is a moderation and defamation risk: sanitise, length-limit, and only list `published` sets. Do not allow sets to contain ICIP or `:request` records unless the set page shows the same prompts. Private sets stored against a guest cookie are lost when the cookie is cleared; say so on screen (or offer an export link).

### 3.5 Embeds, oEmbed, share and download

- **Embed.** A record page offers an embed code. The code comes from a small oEmbed provider service: it receives the record address, looks up the record, and answers with an "iframe" snippet whose source is a separate embed service, but only if the media type is audio, image or video *and* the rights are one of public domain mark, CC0, CC BY or CC BY-SA; otherwise it answers with a plain "link" type ([oembed.js](https://github.com/europeana/oembed.js), [ItemEmbedCodeSnippet.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemEmbedCodeSnippet.vue)). Width and height are limited by the request, and the thumbnail is fetched at a nearby width. The iframe page itself is served by a [media-embed-service](https://github.com/europeana/media-embed-service) which reads the record's IIIF manifest. A debug page (`/debug/oembed`) exists for testing.
- **Share and download.** Share buttons and a citation snippet, plus a download button that goes through a media proxy (the proxy sets the download or inline disposition; PDFs are shown inline in a browser frame).
- **Mapping to us.** Embedding is exactly the `:open` tier (public domain), so `AccessPolicy.download?` can gate the embed button; a minimal embed page `/embed/records/:id` that shows only the image, title, credit line, licence and a link back, plus `/oembed?url=` returning JSON, can be built from `RecordMedia` and `StructuredData`. Set `X-Frame-Options`/`frame-ancestors` only for the embed route, and keep `BotGuard`. Gallery embeds are a second step (a gallery iframe listing only `:open` items).
- **Risks.** An embed can be reused out of context; always show credit and licence inside the frame. Never offer an embed for `:view_only` or `:request` records.

### 3.6 Viewers: image, 3D, audio/video, PDF, annotations, full text

- **Image.** The portal uses OpenLayers with IIIF Image API tiles ([MediaImageViewer.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/media/MediaImageViewer.vue)); it draws annotation rectangles on the image, supports rotation, zoom and a keyboard-mode toggle. We already use OpenSeadragon, which does the same job; keep it.
- **3D.** Google's open `<model-viewer>` web component loaded from a CDN ([Media3DViewer.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/media/Media3DViewer.vue)). Easy to add if the University ever has glTF models; none exist in our data.
- **Audio/video.** `video.js` with text tracks (subtitles) built from annotations ([MediaAudioVideoPlayer.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/media/MediaAudioVideoPlayer.vue)). We have three media records; the native HTML player plus `<track>` captions is sufficient.
- **PDF.** An inline frame pointing at the browser's own PDF viewer, via the media proxy ([MediaPDFViewer.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/media/MediaPDFViewer.vue)). Nothing complex; we can do the same.
- **Annotations list and search.** The record's IIIF Presentation manifest names an annotation page per canvas and a search service. The portal fetches annotations (text lines or words, with their pixel rectangles), lists them next to the viewer, highlights the one under the cursor, and a "search in this item" box queries the manifest's search service and highlights hits. The URL parameter `fulltext` remembers the query ([MediaAnnotationList.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/media/MediaAnnotationList.vue), [MediaAnnotationSearch.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/media/MediaAnnotationSearch.vue), [composables/itemMediaPresentation.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/composables/itemMediaPresentation.js)).
- **Full text** is served by a separate Fulltext API (OCR or transcription stored as annotation pages and resources, with a Solr index for search; mostly newspapers) ([fulltext-api](https://github.com/europeana/fulltext-api)).

### 3.7 Browse, themes, collections, exhibitions, stories (the editorial model)

Europeana's editorial pages live in Contentful (a hosted CMS); the content model is visible in migration scripts ([packages/contentful/migrations](https://github.com/europeana/portal.js/tree/master/packages/contentful/migrations)). Content types we should know about, with the fields that matter:

| Type | Purpose and key fields |
|---|---|
| Story (blog post) | title, URL slug, subtitle, description, featured image, ordered sections, authors, publish date, theme, related entities, optional content warning, associated media |
| Exhibition and Exhibition chapter | title, slug, headline, text, hero image, ordered chapters, credits; each chapter is its own page |
| Image gallery / curated set | images or record ids, attribution, content warning |
| Theme page | slug limited to the fixed list of themes, description, image, ordered sections |
| Browse (landing) page | sections made of card groups, calls to action, topic groups, person groups, gallery groups |
| Automated card group | a block filled by a query ("Recent items", "Featured topics", "Trending"); optional media-type counts |
| Content warning | a reusable warning that can be attached to a story, gallery or exhibition |
| Map section, embed section, illustration/image-with-text group, testimonial, event, project, static page | layout and promotion blocks |

Two design points worth taking: a **reusable content warning** object (we need this for ICIP and medical content), and **automated card groups** (editorial blocks that fill themselves from a query so the home page is never stale). Stories link to *entities*, which is how an entity page finds its stories.

**Mapping to us.** Authoring in Markdown files with front matter (title, slug, hero record id, sections, related creator/subject slugs, `content_warning`, `published_at`) under version control gives the same model without a CMS, and the pull-request flow gives free review. The home page's Featured/Trending/Recent blocks are automated card groups over Solr queries. Section 6 items J and K.

### 3.8 Map, location, and the multilingual features

- **Map.** The `/map` page is a map of *organisations* (data providers), not records ([pages/map/index.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/pages/map/index.vue)); a separate Europeana map web component is loaded from a CDN. A record page can show a small location map from the record's coordinates ([ItemLocationMap.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemLocationMap.vue)). In the Solr schema coordinates are LatLonPoint fields (record location, coverage location, current location) ([search metadata schema](https://github.com/europeana/search/blob/master/solr_confs/metadata/conf/schema.xml)). A geographic *search* by bounding box is possible against these fields.
- **Multilingual.** (a) Every text value is a *language map* (language code to list of values); the portal picks the visitor's language, then English, then any. (b) A toggle button in the search box ("multilingual search") turns on translation of the query: the search API gets the profile "translate" plus source and target languages and runs the query in the other language(s) too ([SearchMultilingualButton.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/search/SearchMultilingualButton.vue), api2 `MultilingualQueryGenerator`). The button asks the visitor to log in, because translation costs money. (c) On a record page, `?lang=xx` shows machine-translated title and description (login-required; logged-out visitors are redirected to the page without it) ([pages/item/_.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/pages/item/_.vue)). (d) Interface strings are in a shared i18n package with about 29 locales. A separate [translation-api](https://github.com/europeana/translation-api) and the CMS automation service "CATS" (in [sea](https://github.com/europeana/sea)) translate content.
- **Mapping to us.** Our records are English; the multilingual need is mainly *interface* languages and community languages. Query translation is of low value until the data is multilingual. Cheap wins: add `lang` attributes to values in other languages; keep the interface in `config/locales/`.

### 3.9 Accounts, likes and API keys

Login goes through an identity service (Keycloak). Features: "likes" (a private special set, heart button on cards), sets, "my galleries", and a self-service page for personal or project API keys with a terms-of-use confirmation. We have no login by design (ADR 0008); a guest-key "saved records" feature (`SAVED_RECORDS=on`) already stands in for likes. API keys are discussed in Section 7 item M.

## 4. Europeana's APIs and indexing

### 4.1 Search and Record API (api2, record-api, search-api)

- **Parameters** ([SearchController.java](https://github.com/europeana/api2/blob/master/api2-war/src/main/java/eu/europeana/api2/v2/web/controller/SearchController.java)): `query`, repeated `qf` filters, `reusability`, `profile`, `start`/`rows` (rows have a cap) or an encoded `cursor` for deep paging (not allowed with `start`), `facet`, `theme`, `sort`, `colourpalette`, `thumbnail`/`media`/`text_fulltext`/`landingpage` booleans, `hit.fl`/`hit.selectors` (highlighting), `q.source`/`q.target`/`lang` (translation), `boost` (an advanced Solr boost, validated to be a single local-params block), `callback` (JSONP).
- **Profiles** set response richness: minimal, standard, rich, facets, hits, params, translate, schemaOrg, portal, debug ([Profile.java](https://github.com/europeana/api2/blob/master/api2-model/src/main/java/eu/europeana/api2/v2/model/enums/Profile.java)). Idea for our public API: one switch for payload size.
- **Theme** is just a `collection:<name>` filter; one theme per request.
- **Facets**: field facets, plus *technical* facets (MIME type, image size, aspect ratio, colour palette, audio/video quality and duration) which are stored as small integers in `filter_tags`/`facet_tags` fields and decoded on the way out ([FacetEncoder and values in metis-framework](https://github.com/europeana/metis-framework/tree/master/metis-indexing/src/main/java/eu/europeana/indexing/search/v2/facet)).
- **Colour palette**: 138 named colours with numeric codes ([ImageColorEncoding.java](https://github.com/europeana/metis-framework/blob/master/metis-indexing/src/main/java/eu/europeana/indexing/search/v2/facet/value/ImageColorEncoding.java)). At ingest the image-processing step runs ImageMagick against a "colour map" image to snap the picture to the palette and keep up to six dominant colours ([ThumbnailGenerator.java](https://github.com/europeana/metis-framework/blob/master/metis-media-service/src/main/java/eu/europeana/metis/mediaprocessing/extraction/ThumbnailGenerator.java)). The search filter then requires the chosen colour codes (AND) against the stored codes. Image size classes are by area (small from 0.1 megapixel, medium 0.42, large 0.95, huge 4); aspect ratio is portrait or landscape.
- **Reusability filter** ([RightReusabilityCategorizer.java](https://github.com/europeana/corelib/blob/master/corelib-web/src/main/java/eu/europeana/corelib/web/model/rights/RightReusabilityCategorizer.java)): the rights URI of every record is placed in one of three buckets; the filter is a precomputed query for each bucket.
  - *open*: Public Domain Mark, CC0, CC BY, CC BY-SA (and "no copyright" marks);
  - *restricted*: CC BY-NC, BY-NC-SA, BY-NC-ND, BY-ND, "Out of copyright, non commercial", "In Copyright, educational use permitted", No Copyright - non commercial, No Copyright - other known legal restriction;
  - *permission*: the in-copyright, orphan-work, unknown and "not evaluated" statements.
  The help text on the site says open can be reused freely (with attribution where the licence requires), restricted has conditions, permission means ask the rights holder. The statistics service uses a finer 14-way split ([RightsCategory.java](https://github.com/europeana/statistics-dashboard-backend/blob/main/statistics-dashboard-common/src/main/java/eu/europeana/statistics/dashboard/common/internal/RightsCategory.java)).
- **Query parsing**: the portal builds the query string; the API passes it to Solr's edismax with default AND; a newer syntax module ([api2 query-syntax](https://github.com/europeana/api2/tree/master/query-syntax)) parses a typed grammar (AND/OR/NOT, field queries, sets, date functions "contains/intersects/within", a distance function) into Solr, which would suit a future rule builder with date-range and "near" rules.
- **Suggestions**: entity suggest (Entity API) powers the search box; there is no record-title suggester in the portal.
- **Sorting and boosting**: sorts are by relevance, timestamps, date fields or random with a seed (used for a "daily shuffle"); there is a page-rank core ([pagerank1 config](https://github.com/europeana/search/tree/master/solr_confs/pagerank1)) used to hold link-based popularity scores.

### 4.2 Europeana's Solr configuration (search repo) compared with ours

([metadata schema](https://github.com/europeana/search/blob/master/solr_confs/metadata/conf/schema.xml), [solrconfig](https://github.com/europeana/search/blob/master/solr_confs/metadata/conf/solrconfig.xml))

| Topic | Europeana | CCS (ours) | Take-away |
|---|---|---|---|
| Analysis | whitespace tokenizer, word-delimiter, lower-case, ASCII folding; no stemming or stop words | ICU tokenizer, ICU folding, stop words, synonyms, English stemming in the catch-all field | Ours is better for English; keep it. Europeana's choice avoids language-specific errors in a 24-language index |
| Relevance | edismax, default operator AND, qf = title^5, creator, description, subject, catch-all; tie 0.1 | qf with five weights, pf, pf3, tie 0.1, `mm` per request | Same family; ours has phrase boosts. No change needed |
| Multilingual | field per language plus language maps; translation at query time | single language | Not needed yet |
| Quality signal | content tier and metadata tier stored as an enumerated field, used as a default filter and ranking aid | `has_digital_asset_bsi` default filter | Add a computed `quality_tier` (0 to 3: asset, description, licence) only if the filter proves useful |
| Dates | date-range fields (`created_date` as range plus begin/end) | integer start/end years | Move to Solr date-range only if circa/approximate dates are added |
| Coordinates | LatLonPoint fields | none | Needed before any map search |
| Spell-check, elevate | spellcheck collation, query elevation | spell fields and collation retry; `elevate.xml` exists | Equivalent |
| More like this | not used by the portal (lexical recipe and a vector engine instead) | not configured | Use the recipe in 3.3 |
| Technical facets | integer-coded tag fields | none | Copy the *idea*: store derived image facts (size class, orientation, dominant colour codes) as small integers or short strings |

### 4.3 EDM data model (corelib) and how ours could map

Europeana Data Model (EDM) separates the **provided object** (the museum's description of the thing), its **web resources** (the images and files), the **aggregation** that ties them to a provider and rights, and **contextual entities** (agent, place, time span, concept). Corelib holds the Java model and rights options ([corelib](https://github.com/europeana/corelib)).

| EDM element | Our field | Notes |
|---|---|---|
| `dc:title`, `dcterms:alternative` | `title_tsim`, `alternative_title_tsim` | direct |
| `dc:creator` / `dc:contributor` | `creator_ssim`, `creator_display_ssim`, `creator_role_ssim` | role can map to `dc:contributor` or a role qualifier |
| `dc:description` | `description_tsim` | |
| `dc:subject`, `dc:type` | `subject_ssim`, `object_type_ssim`, `classification_ssim` | |
| `dcterms:medium` | `material_ssim` | |
| `dcterms:created` / `dc:date` | `production_date_ssim`, `date_start_isi`, `date_end_isi` | |
| `dcterms:spatial` | `production_place_ssim` | |
| `dcterms:isPartOf` / `hasPart` | `parent_record_ssi`, `series_ssim`, `named_collection_ssim` | |
| `edm:dataProvider` | `collection_ssim` (the museum) | |
| `edm:provider` | the University of Melbourne (constant) | |
| `edm:isShownBy` / web resource | `digital_asset_paths_ssim`, `digital_media_ssim` | |
| `edm:object` (thumbnail) | `thumbnail_path_ssi` | |
| `edm:rights` | see the table in 4.5 | needs a URI |
| `edm:type` (IMAGE, TEXT, SOUND, VIDEO, 3D) | `digital_asset_format_ssim` | |
| contextual entity URI | none | the main gap |

Use: a JSON-LD or EDM export of a record (for a public API and for aggregators such as the National Library's Trove or Europeana itself) is a small mapping module once rights URIs exist.

### 4.4 IIIF manifests: Europeana's generator versus our `IiifManifest`

Europeana's [iiif-manifest-api](https://github.com/europeana/iiif-manifest-api) fetches the record, then builds a v2 or v3 manifest, adding a check with the Full-Text API to link annotation pages; manifests are served at `/presentation/<dataset>/<record>/manifest`. A newer [iiif-presentation-api](https://github.com/europeana/iiif-presentation-api) also builds collections from sets and galleries.

What its v3 mapping includes ([EdmManifestMappingV3.java](https://github.com/europeana/iiif-manifest-api/blob/master/src/main/java/eu/europeana/iiif/service/EdmManifestMappingV3.java)) and how we compare:

| Manifest feature | Europeana | Ours (`iiif_manifest.rb`) | Gap |
|---|---|---|---|
| Label, language maps | many languages | English only | low |
| Summary (description) | yes, avoiding duplication with the label | no | add (from `description_tsim`) |
| Metadata pairs | date, format, relation, type, language, source, with all language labels | accession number, licence | add date, creator, medium, place, object type |
| Required statement | attribution | yes | ok |
| Rights URI | from `edm:rights` | only 3 licence values | map all licences (4.5) |
| Provider, homepage | yes | yes | ok |
| `navDate` | record date | no | add when a clean date exists |
| Thumbnail on manifest and each canvas | yes | manifest only | add per-canvas thumbnails |
| `start` canvas | yes | no | trivial |
| `seeAlso` (machine-readable record, e.g. EDM, JSON-LD) | yes | no | add once an export exists |
| `service` for content search | yes (IIIF Content Search) | no | needs full text |
| Canvas order | follows "next in sequence" links between web resources | file order | needed for multi-page items |
| Audio/video canvases (duration) | yes | images only | needed for 3 media records |
| `partOf` (collections) | yes | no | add for parent/child records |
| Per-canvas annotations (full text, transcripts) | yes | no | later |
| Image service on canvases | when present | when `info.json` present | ok |

Europeana also keeps `rights` out when it cannot map to the two allowed families, as we do.

### 4.5 Rights statements: mapping our `licence_type_ssim` values

Sources: [Europeana's available rights statements](https://github.com/europeana/EuropeanaLicensingFramework/blob/master/available-rights-statements.md) (14 statements; CC0 text), [RightsStatements.org data model](https://github.com/rightsstatements/data-model) (with the 12 statements, including In Copyright, No Copyright - US, Copyright Not Evaluated, Copyright Status Unknown) and the categoriser above.

| Our value (records) | Our `AccessPolicy` tier | Proposed machine-readable rights URI | Europeana reusability class | Notes |
|---|---|---|---|---|
| Public domain - Copyright expired (4,005) | open | `http://creativecommons.org/publicdomain/mark/1.0/` (Public Domain Mark) | open | Already used by `IiifManifest`. Check separately whether the *digitisation* is also released |
| Copyright - Current (3,421) | view_only | `http://rightsstatements.org/vocab/InC/1.0/` (In Copyright) | permission | Already used by `IiifManifest` |
| Copyright (587) | view_only | `http://rightsstatements.org/vocab/InC/1.0/` | permission | Same |
| Reproduction Licence - Current (1,760) | view_only | `http://rightsstatements.org/vocab/InC/1.0/` | permission | A University licence to reproduce is permission-based. If the licence allows educational use specifically, `InC-EDU` (restricted class) applies, but only with the rights team's confirmation |
| Reproduction Licence - Requested (33) | view_only | `http://rightsstatements.org/vocab/InC/1.0/` (provisional) | permission | No licence yet; rights team to confirm |
| Reproduction Licence - The University of Melbourne (13) | view_only | `http://rightsstatements.org/vocab/InC/1.0/` | permission | The University is the rights-holder, so it could choose a Creative Commons licence; a policy decision, not a technical one |
| Reproduction Licence - Restricted (1) | request | `http://rightsstatements.org/vocab/InC/1.0/`, with the asset withheld | permission | The restriction is access, which RightsStatements.org does not express |
| Restricted Access (2) | request | no URI; show the access label | none | Access is not copyright. Do not publish a rights URI that implies reuse |
| ICIP Rights (29) | request | no URI. Do not map | none | RightsStatements.org and Creative Commons have no ICIP concept. Show the University's ICIP notice. Some records carry two values in `rights_ssim` (an ICIP value plus a copyright value); the stricter rule already wins. Whether to adopt Local Contexts Traditional Knowledge or Biocultural labels is a question for the Indigenous cultural advisers; it is outside Europeana's material |
| blank (31,111) | view_only | `http://rightsstatements.org/vocab/CNE/1.0/` (Copyright Not Evaluated) once agreed; until then publish no URI | none | Do not infer public domain. The honest label is "not evaluated" |

The `access_condition_ssi = Community Restricted` rule still overrides all of this. "Free to reuse" in the interface should mean exactly the open class: 4,005 records, 62 with a digital asset today.

### 4.6 Other Europeana services read

| Service | What it is | Idea for us |
|---|---|---|
| [thumbnail-api](https://github.com/europeana/thumbnail-api) | serves thumbnails from object storage; the portal builds the address from a size and an md5 hash of the source address; fixed sizes of 200 and 400 pixels (generated in the ingest step; modern service stores WebP); no key required | pre-generate two or three derivative sizes per asset at deploy (e.g. 200, 400, 800 wide, WebP) and name them by a hash; cache for a long time with immutable headers. Today the site serves the original with a `thumbnail_path_ssi` |
| [api-proxy-cache](https://github.com/europeana/api-proxy-cache) | a small Express server that proxies API calls and caches replies in Redis | a public API would need response caching; `Rails.cache` with ETag/`stale?` is enough at our scale |
| [statistics-dashboard](https://github.com/europeana/statistics-dashboard) and [backend](https://github.com/europeana/statistics-dashboard-backend) | public dashboard of what is in Europeana: by dataset, type, country, provider, data provider, rights and rights category, content tier, metadata tier, created and updated date, with historical snapshots | a staff page of collection health: records per museum, % with images, % with licence, % with description, by month. It would show the data-quality gaps that block features. The dimensions are a ready checklist |
| [europeana-contribute](https://github.com/europeana/europeana-contribute) (Ruby on Rails, archived 2023) | a platform for the public to contribute stories and objects. Ideas: campaigns with their own rules and licences; a draft-to-published-to-deleted state machine; age and guardian consent checks; acceptance of a content policy and a display-and-takedown agreement; roles for staff and event hosts; thumbnails made by a background job; autocomplete from Getty AAT, GeoNames and UNESCO vocabularies; export in the standard data model through OAI-PMH | if we ever accept community contributions (for example community-supplied descriptions): state machine, takedown clause, and vocabulary autocomplete. Its Mongo/Redis/S3 stack is heavier than ours |
| [sea](https://github.com/europeana/sea) | "Service Experience Architecture": a monorepo of Europeana's *other* websites (a data space for cultural heritage site, a Contentful translation service "CATS", Contentful apps) plus shared Vue components and styles | confirms Europeana runs editorial sites and the search portal as separate apps sharing a design system. For CCS: one design system, many apps |
| [metis-framework](https://github.com/europeana/metis-framework) | the ingest pipeline (validation, enrichment, media processing, indexing) | our `Collections::Indexer` is the equivalent. Worth borrowing: a *media processing step* separate from indexing |
| [Europeana licensing framework](https://github.com/europeana/EuropeanaLicensingFramework) | terms of use, public domain charter, data-exchange agreement, usage guidelines, the list of rights statements (CC0) | reuse the wording ideas for our own "how you may use this" pages after legal review |

### 4.7 Research and development repositories

| Repository | What it does | Relevance |
|---|---|---|
| [rd-img-classification-pilot](https://github.com/europeana/rd-img-classification-pilot) | builds a training set from Europeana records tagged with chosen concepts, and trains a PyTorch image classifier (single and multi-label) with cross-validation | Shows the method for auto-tagging images; needs thousands of images per class, so it is out of reach for 137 images |
| [rd-img-tagging](https://github.com/europeana/rd-img-tagging) | scripts to harvest images, map a tag vocabulary and tag images automatically | Same; useful as a process outline |
| [rd-duplicate-detection](https://github.com/europeana/rd-duplicate-detection) | finds near-duplicate images using an off-the-shelf tool | Duplicate/variant detection for photographic collections later |
| [rd-watermark-detection](https://github.com/europeana/rd-watermark-detection) | model to find watermarks in images | Quality control for digitised images |
| [rd-img-superresolution](https://github.com/europeana/rd-img-superresolution) | a service that upscales low-resolution images | Not recommended (alters cultural material) |
| [rd-img-utilities](https://github.com/europeana/rd-img-utilities) | tools to fetch images from object storage with an id-to-hash database | Not applicable |
| [api-image-similarity](https://github.com/europeana/api-image-similarity) (archived 2019) | an image similarity search API (README only says that) | Evidence that Europeana tried visual similarity early |
| [rd-europeana-translate](https://github.com/europeana/rd-europeana-translate) and [translation-api](https://github.com/europeana/translation-api) | gather multilingual metadata and provide machine translation | Multilingual metadata, later |
| [rd-iiif-discovery-crawling](https://github.com/europeana/rd-iiif-discovery-crawling) (Apache-2.0) | crawls IIIF Change Discovery feeds and keeps local copies of linked metadata | If we publish a Change Discovery feed, others can harvest us |
| [vector-db-benchmark](https://github.com/europeana/vector-db-benchmark) (Apache-2.0) | framework to compare vector search engines | Europeana weighed vector engines; Solr 10 now makes a separate engine unnecessary at our size |

No colour code is in these repos; colour is in metis-framework (4.1). There is no standalone DE-BIAS source repository in the organisation: the portal reads DE-BIAS results as annotations.

## 5. De-bias notices (Europeana DE-BIAS)

**How it works.**
1. **Terms and explanations come from a reviewed vocabulary** built by the DE-BIAS project with community and expert input (Europeana's project page: pro.europeana.eu/project/de-bias). Each term has a definition, a note on its origin, recommendations (scope note) and alternative labels, in several languages.
2. **Matching happens before the visitor arrives**, outside the portal. A detector finds terms in a record's descriptive fields and publishes a W3C Web Annotation for each occurrence, with the purpose "highlighting"; the annotation's *target* names the record, the field and a text quote selector (the exact words, with optional text before and after to find the right occurrence), and its *body* points to the vocabulary term ([composables/deBias.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/composables/deBias.js)).
3. **The record page** loads the annotations with the record, then wraps each match in the field text with an underlined term and a small button; on hover, focus or click a tooltip shows the definition and a link ([ItemDebiasField.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemDebiasField.vue), [ItemDebiasTerm.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemDebiasTerm.vue)). The button has a screen-reader label naming the project.
4. **A page per term** (`/debias/<number>-<term>`) shows the term as a quotation heading, definition, source note, recommendations and alternatives, and a short background paragraph about the project ([pages/debias/_.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/pages/debias/_.vue)). The term is looked up by querying the Annotation API for the body address.
5. **Feedback**: the portal itself has no feedback form for de-bias terms. Its Annotation API has endorse and report votes for annotations in general, and the record page links to a way of contributing annotations. For us, a visible "tell us about this notice" link is a cheap, important addition.

**Mapping to us.** Do the matching at index time or render time using a *local* reviewed list (YAML or a database table): term, matching rule (exact words, case-insensitive, optional word boundary and field list), explanation, why it may harm, suggested alternatives, source, reviewer, date. Render with the same safe pattern as `SearchHighlighting` (escape all text, mark matches by position). Show it on the record page, in the fields that are shown, with an accessible pattern: a real button with a text label, `aria-describedby`, keyboard and touch support, and a visible note that the original catalogue wording is unchanged. Do not alter or hide the original text.

**Gaps and risks.** Europeana's vocabulary is European and largely about colonial, racial and gendered language in European contexts; much of it will not fit Australian museum material. The Indigenous language and cultural-protocol layer (naming of people who have died, culturally sensitive words) needs to be written with Aboriginal and Torres Strait Islander advisers, not adopted from Europeana. Start with a short list and a review workflow. Free-text matching creates false positives (a surname, a place name, a quotation); allow per-record exceptions.

## 6. Google Arts & Culture (public pages and Google's blog only)

Verified from the live home page (artsandculture.google.com) and Google's blog posts ([Camera tab post](https://blog.google/company-news/outreach-and-initiatives/arts-culture/explore-art-and-culture-through-new-lens/), [10th anniversary](https://blog.google/company-news/outreach-and-initiatives/arts-culture/google-arts-culture-turns-10/), [AR colour gallery](https://blog.google/outreach-initiatives/arts-culture/explore-art-and-color-our-latest-ar-gallery/)). Where marked "(background)", the item is widely known but was not re-verified here.

| Feature (what the public site shows) | Feasible with Blacklight, Solr and Rails? |
|---|---|
| Browse by category pages: artists, mediums, art movements, historical events, historical figures, places | **Yes** for artists, mediums (`creator_ssim`, `material_ssim`, `object_type_ssim`), places (`production_place_ssim`). **Needs data** for movements, events and figures (no such fields; a controlled vocabulary or Wikidata links would be needed) |
| Browse by colour (a colour picker leading to a results page with the colour in the URL) | **Needs new dependency and data**: image analysis at ingest (ImageMagick or similar) and a colour field. Works only for records with images (137 today) |
| Browse by time | The home page shows "today in history" but no time route. A timeline or decade browse is **yes** with `date_start_isi` (28,264 records) |
| Stories (long-form illustrated articles) | **Yes** with Markdown stories (Section 7 item K) |
| Themes and Collections (partner pages) | **Yes**; we already have five collections |
| Explore and Discover, Today in history, Nearby | Explore/Discover: **yes** as curated/automated blocks. Nearby: **needs data** (coordinates) and device location (privacy) |
| Favourites, "my galleries" (profile) | **Yes** with guest lists (already built) and shareable galleries; sign-in is **not needed** |
| Zoomable artwork pages with detail view | **Yes** (OpenSeadragon, already built; needs deep-zoom/IIIF tiles for high-resolution assets) |
| Gigapixel "Art Camera" images (background) | **Not feasible** as a software feature: it is a hardware robot camera. The viewing side is feasible if the University scans at high resolution |
| Street View gallery tours (e.g. museum walk-throughs) | **Not feasible** in the stack: it relies on Google imagery. A 360-degree panorama viewer is possible with a library, if the University captures photos |
| AR: Pocket Gallery, Art Projector (life-size artwork in your room), AR colour gallery | **Needs new dependency**: browser WebXR or `<model-viewer>` for AR placement on phones; works only with a scale (dimensions field is a data gap) and an image. Low priority |
| Art Selfie (face matching to portraits) | **Not recommended**: biometric matching, privacy and consent risk, and requires a trained model |
| Color Palette / Art Palette (photograph, find artworks of matching colours) | **Needs new dependency and data**: same colour index plus an in-browser colour extractor. Feasible as a later add-on to colour search |
| Experiments: art colouring book, filters, games and quizzes ("Who painted this?") | Quizzes: **yes** with simple Rails code over records that have an image and a clear creator. Colouring and filters: **needs a new front-end dependency**, optional |
| Search with filters, a visual "search by image" (background) | Text: **yes**. Search by image: **needs new dependency** (vector search, Section 7 item N) |
| Offline / app (the Camera tab is in the mobile app) | A PWA is **yes** for web content; the camera features are not |

Take-aways that cost little: colour as an "explore" route, a "time" strip, curated stories and quizzes, favourites that need no login.

## 7. Roadmap

Effort: S (about 1 to 3 days), M (about 1 to 2 weeks), L (more than 2 weeks), for one developer including tests and accessibility. "Data" means what we must obtain from the University; "Infra" means anything beyond the current web, Postgres and Solr. Europeana files that best explain each item are linked.

### 7.1 The five items now being built

| # | Item | Effort | Dependencies | Risks | What to read |
|---|---|---|---|---|---|
| A | **Entity pages and browse hubs** (creators, subjects, places, object types, materials as hubs; related; browse index and sortable table) | M | Data: slug table; name clean-up; hide "Unknown". No new gems. Solr: facet queries (cache) | Indigenous creators and communities: review before listing; ICIP records still gated on hub pages. Duplicated names. Performance of 7,821-value facets (page and cache) | [collections page](https://github.com/europeana/portal.js/blob/master/packages/portal/src/pages/collections/_type/_.vue), [related card](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/entity/EntityRelatedCollectionsCard.vue), [type browse](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/entity/EntityTypeBrowse.vue), [table](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/entity/EntityTable.vue) |
| B | **Shareable galleries and embeds** | M to L | Postgres migration on lists (title, description, visibility, token, published_at); staff review page; embed route and oEmbed JSON; frame headers | User text moderation; rights (embed only `:open`); privacy of guest lists; link-sharing leaks; copyright of images in galleries | [set.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/plugins/europeana/set.js), [publication request](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/set/SetPublicationRequestWidget.vue), [oembed.js provider](https://github.com/europeana/oembed.js/blob/master/src/providers/europeana.js) |
| C | **Similar items and trending/featured** | S (similar), M (trending), S (featured) | `SimilarRecords` Solr recipe; `record_events` table; nightly roll-up (no job runner is in use, so use a rake task and a scheduler, or compute on read with caching) | Trending amplifies sensitive material (exclude `:request` and sensitive); analytics privacy; noise at low traffic | [similarItems.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/mixins/similarItems.js), [trending.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/server-middleware/api/events/trending.js) |
| D | **Rule-based advanced search and the free-reuse switch** | M | Reuse Blacklight clause params; Stimulus controller; `FreeReuseFilterField` over `AccessPolicy` tiers (index a `reuse_class_ssi` field at indexing time so the filter is a plain `fq`, not a runtime computation) | Two parameter schemes; accessibility of repeatable rows; "free to reuse" must not over-promise (76% of records have no licence; say "licence recorded as public domain") | [advancedSearch.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/mixins/advancedSearch.js), [SearchSwitchFilter.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/search/SearchSwitchFilter.vue), [RightReusabilityCategorizer.java](https://github.com/europeana/corelib/blob/master/corelib-web/src/main/java/eu/europeana/corelib/web/model/rights/RightReusabilityCategorizer.java) |
| E | **De-bias notices** | M (mechanism), L (content) | A reviewed term list with explanations; render-time matcher; term pages; feedback link | Wrong or offensive terms in the list; Indigenous protocols; false positives; accessibility of tooltips; must not change source text | [composables/deBias.js](https://github.com/europeana/portal.js/blob/master/packages/portal/src/composables/deBias.js), [ItemDebiasTerm.vue](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemDebiasTerm.vue), [debias page](https://github.com/europeana/portal.js/blob/master/packages/portal/src/pages/debias/_.vue) |

### 7.2 Next candidates

| # | Item | Effort | Dependencies | Risks | What to read |
|---|---|---|---|---|---|
| F | **Colour search and image pipeline** (derivatives, dominant colours, size/orientation) | M (pipeline) + data wait | Data: the DAM feed (only 137 images now). New: ImageMagick or libvips (`ruby-vips` gem) in the Docker image; storage for derivatives; one-off indexer step; a fixed palette; `dominant_colours_ssim`, `image_orientation_ssi`, `image_size_class_ssi` | Memory on large TIFFs; colour of faded or monochrome photographs gives little value; rights (derivatives of restricted assets must also be restricted) | [ImageColorEncoding](https://github.com/europeana/metis-framework/blob/master/metis-indexing/src/main/java/eu/europeana/indexing/search/v2/facet/value/ImageColorEncoding.java), [ThumbnailGenerator](https://github.com/europeana/metis-framework/blob/master/metis-media-service/src/main/java/eu/europeana/metis/mediaprocessing/extraction/ThumbnailGenerator.java), [ImageSize](https://github.com/europeana/metis-framework/blob/master/metis-indexing/src/main/java/eu/europeana/indexing/search/v2/facet/value/ImageSize.java) |
| G | **Visual or semantic similarity with Solr 10 dense vectors** | L | Embedding model (image: CLIP-style; text: multilingual sentence model), batch job, `DenseVectorField` and a k-nearest-neighbour query in Solr 10; schema change owned by the dev team | Needs images (or good text); hosting a model; bias of models on Indigenous art; cost; explainability ("why is this similar?") | [recommendation-api](https://github.com/europeana/recommendation-api), [recommendations-updater](https://github.com/europeana/recommendations-updater), [embedding-api](https://github.com/europeana/embedding-api) |
| H | **Full-text search of PDFs and documents** | M to L | Text extraction (Tika or `pdftotext`) at indexing; a text field with highlighting; page-level index for "jump to page"; OCR for scans (Tesseract) | Rights (do not index or snippet `:request` records); index size; OCR quality; Grainger archive letters may contain private material | [fulltext-api](https://github.com/europeana/fulltext-api), [fulltext schema](https://github.com/europeana/search/tree/master/solr_confs/fulltext/conf) |
| I | **Annotations and transcription** | L | W3C Web Annotation store (Postgres JSON), annotation page endpoints in the manifest, a transcription form, review queue, a moderation record with endorse and report | Moderation load; privacy; vandalism; Indigenous knowledge being written into records by the public; needs logins or at least nicknames | [annotation model](https://github.com/europeana/annotation/tree/master/annotation-definitions/src/main/java/eu/europeana/annotation/definitions/model), [MotivationTypes](https://github.com/europeana/annotation/blob/master/annotation-definitions/src/main/java/eu/europeana/annotation/definitions/model/vocabulary/MotivationTypes.java), [europeana-contribute](https://github.com/europeana/europeana-contribute) |
| J | **Map browse and geocoding** | L | Data: a gazetteer lookup (GeoNames or Pelias) over 1,018 place strings, reviewed by hand; `LatLonPointSpatialField` in Solr; a map library (Leaflet or MapLibre) with open tiles | Place strings are often continents; wrong coordinates mislead; some places are culturally sensitive (sacred sites); tile-service terms and privacy (external requests) | [search schema location fields](https://github.com/europeana/search/blob/master/solr_confs/metadata/conf/schema.xml), [ItemLocationMap](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemLocationMap.vue) |
| K | **Stories and exhibitions authored in Markdown** | M | Markdown with front matter in the repo (or `content/`), a loader with validation (slug, hero record, related slugs, content warning), ViewComponents for sections, a preview command; record "cards" resolved from Solr by id | Broken record references (validate in CI); rights of images in stories; Indigenous review; authoring by non-developers needs a simple guide | [story and exhibition migrations](https://github.com/europeana/portal.js/tree/master/packages/contentful/migrations) (0007, 0050, 0132) |
| L | **Multilingual interface and metadata translation** | M (interface), L (metadata) | Rails i18n already in `config/locales/`; language selection and `lang` attributes; for metadata, a translation service and a review policy | Machine translation of Indigenous names and cultural terms is harmful; cost; accuracy; keep original text primary | [i18n package](https://github.com/europeana/portal.js/tree/master/packages/i18n/src), [SearchMultilingualButton](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/search/SearchMultilingualButton.vue), [translation-api](https://github.com/europeana/translation-api) |
| M | **A public API with keys** | L | Versioned JSON endpoints (search, record, IIIF), a `profile` switch for payload size, API-key table and quotas (Rack throttling already exists), documentation (OpenAPI), caching | Reuse beyond licence terms; scraping of withheld records (must apply `AccessPolicy` server-side); support burden; privacy of keys | [SearchController](https://github.com/europeana/api2/blob/master/api2-war/src/main/java/eu/europeana/api2/v2/web/controller/SearchController.java), [Profile](https://github.com/europeana/api2/blob/master/api2-model/src/main/java/eu/europeana/api2/v2/model/enums/Profile.java), [apikey](https://github.com/europeana/apikey), [api-proxy-cache](https://github.com/europeana/api-proxy-cache) |
| N | **PWA / installable site and offline** | S to M | Web manifest, service worker for shell and saved lists, cache rules that never store withheld assets | Caching restricted or sensitive images on a device; stale content; the sensitivity prompt must re-run | none from Europeana (not a feature there); see Google Arts & Culture's app (section 6) |
| O | **Collection health dashboard** (staff) | S | Facet queries; a staff-only page | Exposes data gaps to the public if not protected | [statistics dashboard backend model](https://github.com/europeana/statistics-dashboard-backend/blob/main/statistics-dashboard-common/src/main/java/eu/europeana/statistics/dashboard/common/internal/model/StatisticsRecordModel.java) |
| P | **Rights URIs and `reuse_class` at index time** (underpins D, B, M and IIIF) | S | Rights-team sign-off on the table in 4.5; an indexer change; `IiifManifest::RIGHTS_BY_LICENCE` extended | Wrongly implying reuse; do not publish URIs for blank values until agreed | [available-rights-statements](https://github.com/europeana/EuropeanaLicensingFramework/blob/master/available-rights-statements.md) |
| Q | **IIIF manifest improvements** (summary, richer metadata, start, canvas thumbnails, partOf, AV canvases) | S to M | None | Metadata leak: only fields already shown on the record page | [EdmManifestMappingV3](https://github.com/europeana/iiif-manifest-api/blob/master/src/main/java/eu/europeana/iiif/service/EdmManifestMappingV3.java) |

### 7.3 Suggested order

1. P (rights URIs and reuse class), because D, B and Q need it. Small, mostly a decision.
2. A, C (similar items), D, in parallel: they need only the data we already have.
3. E (mechanism first, while the term list is written with advisers) and B.
4. Q, O, then K.
5. F and G only when the DAM feed supplies more images; H and I once rights and moderation capacity are agreed; J after a place clean-up; L, M, N last.

### 7.4 Quick wins we missed

- **Give the three reuse classes plain words** and show the class on cards and the record page, not only in the filter (cheap; builds on `AccessPolicy`).
- **Co-occurrence "related" lists** on the record page: "Other records by this creator" and "More records about <top subject>" with one facet query each.
- **Daily shuffle** on the home page: Solr random sort with a date seed, so a featured strip changes every day without an editor ([ItemTrendingItems](https://github.com/europeana/portal.js/blob/master/packages/portal/src/components/item/ItemTrendingItems.vue) uses this for its mock).
- **A default URL stays clean**: drop parameters that equal their defaults (the switch-filter idea) so shared links and the canonical URL are short.
- **Cap deep paging** (for example 1,000 results) and say so on screen; protects Solr and bots.
- **Log which "similar items" algorithm produced a click, with rank**, from day one, so changes can be judged.
- **Record the rights URI in `StructuredData`** (schema.org `license`) and in the IIIF manifest, so search engines and viewers show it.
- **Collection health numbers** (item O) as a monthly email-free report to data owners.
- **Hide cataloguing noise** ("Unknown", "Exhibition", "DOCUMENTS--Letters") from public hubs and related lists with a small deny-list in YAML.
- **A "contribute a correction" link** on each record (a form into the existing access-request style store), cheap precursor to annotations.

### 7.5 Things Europeana does that we should not copy, and why

- **Do not make translation a login feature.** Europeana did it to control cost; we have no accounts and little multilingual data.
- **Do not depend on a hosted CMS** for stories; Markdown in the repo is simpler, reviewable and free.
- **Do not copy its European de-bias term list** as is; it is not written for Australian or Indigenous contexts.
- **Do not auto-tag images with a classifier** (their R&D pilot). Mislabelling cultural material, especially Indigenous and human remains, is a harm; keep tags human-reviewed.
- **Do not upscale or "enhance" images** (their super-resolution experiment): it changes the object.
- **Do not trend everything.** Europeana's trending counts any record; ours must exclude restricted and sensitive records.
- **Do not publish a rights statement we have not verified.** Europeana relies on providers to supply rights; we should not invent one for 76% of records.
- **Do not use a microservice per feature** (a dozen Java services and a vector database). At 41,000 records, one Rails app and Solr 10 do the work.
- **Do not allow crowdsourced annotations without moderation capacity.** Their moderation machinery (votes, reports, roles) is a staffing commitment, not just software.
- **Do not load map, 3D and player libraries from public CDNs.** Europeana does; for privacy and the University's content-security rules, vendor them (as we already do with OpenSeadragon).
- **Do not offer wide-open embeds.** Only the open class, with credit and licence inside the frame.

## 8. Limits of this research

- europeana.eu returned HTTP 403, so live behaviour was inferred from source code, not observed. Some behaviours (for example the exact wording of the reusability filter on the site) are described from code only.
- Vendor documentation on pro.europeana.eu and Europeana's wiki was not fetched; only GitHub was read. The DE-BIAS vocabulary itself and the DE-BIAS detector are not in the organisation's public repositories.
- Google Arts & Culture was read from one page fetch and Google's blog search results; "Art Camera" and "search by image" are from background knowledge and flagged.
- Large repositories (api2, metis-framework, search, portal.js) were read selectively. The list of files read is in the sources document.
- Rights mapping in 4.5 is a proposal for the rights team and the University's legal advisers; it is not legal advice.
