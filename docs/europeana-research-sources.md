# Europeana research: sources read

Companion to [europeana-research.md](europeana-research.md). Everything was read through the GitHub read-only API on 3 to 4 November 2026 (default branch at that time), except the two Google pages. Europeana repositories are EUPL-1.2 unless noted; this table records what was learned, in our own words. No code was copied.

Base address for all repositories: `https://github.com/europeana/<repo>`. Paths below are relative to the repository root.

## Our own repository and index (local, read-only)

| Source | What it gave us |
|---|---|
| `docs/architecture.md` | Stack, objects, Solr/Postgres split, no logins, no background jobs |
| `ead-ccs-test/config/data_model/solr_mapping.yml` | Workbook field and filter mapping, which fields are gaps |
| `ead-ccs-test/solr/conf/schema.xml`, `solrconfig.xml` | ICU analysers, synonyms, edismax weights, pf/pf3, Solr 10 (`luceneMatchVersion` 10.0.0) |
| `ead-ccs-test/app/models/catalog_config/facets.rb` | Facets from the workbook, `InclusiveFilterField`, digital-asset option |
| `ead-ccs-test/app/models/iiif_manifest.rb` | Presentation 3.0 manifest, three licence-to-rights mappings |
| `ead-ccs-test/app/models/access_policy.rb` | Three tiers and the licence table with record counts |
| `ead-ccs-test/app/models/search_highlighting.rb` | Escaped highlighting pattern, reusable for de-bias rendering |
| Shared Solr, `http://127.0.0.1:8984/solr/blacklight-core` (read-only: luke field list, facet counts, field-presence counts, system info) | 40,962 records; 137 with assets; 31,111 without a licence value; 7,821 creators, 1,601 subjects, 1,018 places; Solr 10.0.0 |

## europeana/portal.js (the search site)

| File or path | What it taught |
|---|---|
| `packages/portal/src/mixins/advancedSearch.js` | Rule model (field, modifier, term), field types, modifier templates, `qa` URL parameter, validation, round trip from URL to rules |
| `packages/portal/src/components/search/SearchQueryBuilder.vue` | Rules in component state, submit pushes a route, tracking per rule |
| `.../search/SearchFilters.vue` | Default and additional facet lists, `qf` format, reusability and sort in their own parameters, theme clears filters, content-tier switch |
| `.../search/SearchSwitchFilter.vue` | Switch with checked, unchecked and default values; default is dropped from the URL |
| `.../search/SearchQueryOptions.vue` | Search-box dropdown: entity suggestions and "search in collection" |
| `.../search/SearchMultilingualButton.vue` | Multilingual search toggle, requires login |
| `.../search/SearchDateFilter.vue` (listed, not read in full) | Date range only for themes with usable dates |
| `packages/portal/src/plugins/europeana/search.js` | 24 per page, 1,000-result cap, translate profile parameters, default content-tier filter rules |
| `.../plugins/europeana/entity.js` | Five entity types and slugs, entity URI to qf query, suggest, retrieve, search, image rules |
| `.../plugins/europeana/recommendation.js` | Recommendation API client (recommend, accept, reject) |
| `.../plugins/europeana/set.js` | Set visibility values, create, publish, unpublish, pin, reposition, items |
| `.../plugins/europeana/annotation.js` | Annotation API search client |
| `.../plugins/europeana/thumbnail.js` | Thumbnail v3 address = size + md5 of source address; 200 and 400 pixels |
| `.../plugins/europeana/media-proxy.js` | Media proxy base only |
| `packages/portal/src/utils/europeana/themes.js` | 14 themes as `collection:` filters; per-theme facets, date and sort |
| `.../mixins/similarItems.js` | Similar-items recipe: weights 0.8 / 0.5 / 0.2 on subject and type, creator, provider; self excluded |
| `.../components/item/ItemRecommendations.vue` | Logged-out lexical recipe vs logged-in recommender; click logging with algorithm and rank |
| `.../components/item/ItemTrendingItems.vue`, `pages/trending/index.vue` | Trending fetch, order preserved, random mock mode |
| `.../server-middleware/api/events/trending.js` | Event weights (view 1, download 2, like 4, add 6), 24-hour window against previous 24 hours, momentum score, Postgres |
| `.../cachers/matomo/visits.js` | Matomo used for visit statistics |
| `.../pages/collections/_type/_.vue` | Entity page assembly: entity fetch, filtered search, best-bets set, related, editorial, redirect to preferred path |
| `.../components/entity/EntityRelatedCollectionsCard.vue` | Related topics from facet counts of a zero-row search, top four |
| `.../components/entity/EntityTypeBrowse.vue` | Paged entity index, 24 per page, sorted by label |
| `.../components/entity/EntityTable.vue` | Sortable, searchable organisation table with counts |
| `.../components/entity/organisations/*`, `pages/map/index.vue` | Map is of organisations, not records |
| `.../components/set/SetPublicationRequestWidget.vue` | Publication request posts a service-desk ticket |
| `.../components/set/SetPublishButton.vue` | Publish and unpublish by role, re-reads before acting |
| `.../components/user/UserSets.vue` | Sets by type and visibility; contributor vs creator |
| `.../pages/galleries/_.vue` | Roles: owner, publisher, entity editor |
| `.../components/item/ItemDebiasField.vue`, `ItemDebiasTerm.vue` | Wrap matched text, tooltip, link to term page, accessible button label |
| `.../composables/deBias.js` | Annotations of purpose "highlighting" become terms, definitions, ids by field and text quote |
| `.../pages/debias/_.vue` | Term page: definition, note, recommendations, alternatives, project blurb |
| `.../components/media/MediaImageViewer.vue` | OpenLayers IIIF viewer, rotation, zoom, annotation rectangles |
| `.../components/media/Media3DViewer.vue` | Google `<model-viewer>` |
| `.../components/media/MediaAudioVideoPlayer.vue` | video.js with text tracks |
| `.../components/media/MediaPDFViewer.vue` | Browser PDF viewer in a frame via media proxy |
| `.../components/media/MediaAnnotationList.vue`, `MediaAnnotationSearch.vue`, `composables/itemMediaPresentation.js` | Annotation pages and search service from the manifest; `fulltext` URL parameter |
| `.../components/item/ItemEmbedCodeSnippet.vue`, `components/embed/EmbedOEmbed.vue` | Embed code from an oEmbed provider |
| `.../components/item/ItemLocationMap.vue`, `components/embed/EmbedEuropeanaMap.vue` | Small record map; map component loaded from a CDN |
| `.../pages/item/_.vue` | Record page: translation by `lang`, annotations, tagging, recommendations, entity badges |
| `.../pages/account/api-keys.vue` | Self-service personal and project API keys |
| Repository tree listing (components, pages, plugins, mixins, store) | Where each feature lives |
| `packages/contentful/migrations/*` (0007, 0045, 0050, 0086, 0089, 0132, 0161 and file names) | Editorial content types and fields |
| `packages/i18n/src/*` (listed) | Shared language-map and locale helpers |

## europeana/oembed.js, media-embed-service, europeana-oembed-provider

| File | What it taught |
|---|---|
| `oembed.js` README, `src/providers/europeana.js`, `src/response.js` | Rich type only for audio, image or video media and rights of public domain mark, CC0, CC BY, CC BY-SA; otherwise a link; iframe response; thumbnail width choice |
| `media-embed-service` README | Embed page built from the IIIF presentation API |
| `europeana-oembed-provider` (listed in organisation, archived Ruby) | Earlier provider; not read |

## europeana/api2, corelib, search, record-api, search-api

| File | What it taught |
|---|---|
| `api2` README | APIs documented at pro.europeana.eu |
| `api2-war/.../web/controller/SearchController.java` | Search parameters, defaults, cursor rules, theme as collection filter, colour palette tags, reusability, translate, boost validation |
| `api2-model/.../enums/Profile.java` | Response profiles |
| `api2-war/.../utils/BoostParamUtils.java` | Boost parameter must be one edismax local-params block |
| `api2/query-syntax/*` (listed) | Typed query grammar with date and distance functions |
| `corelib` tree; `corelib-web/.../rights/RightReusabilityCategorizer.java` | Open, restricted, permission buckets by rights address |
| `corelib-definitions/.../model/RightsOption.java` (partly) | List of supported rights options and labels |
| `search` README; `solr_confs/metadata/conf/schema.xml` | Field types, analyzers (whitespace, word-delimiter, lower-case, ASCII folding), tier fields, location fields, date-range fields, integer filter and facet tag fields |
| `search`: `solr_confs/metadata/conf/solrconfig.xml` | edismax with AND, qf weights, spell-check collation, elevation |
| `search`: `solr_confs/pagerank1/conf/schema.xml` | Page-rank score field in a separate core |
| `record-api`, `search-api` | Listed (v3 split of Search and Record APIs); README-level only, not studied in depth |
| `metis-framework`: `metis-indexing/.../facet/value/ImageColorEncoding.java`, `ImageSize.java`, `ImageAspectRatio.java` | 138-colour palette with numeric codes; size classes by area; orientation |
| `metis-framework`: `metis-media-service/.../ThumbnailGenerator.java`, `ThumbnailKind.java` | ImageMagick with a colour-map image; up to six colours; thumbnail sizes 200 and 400 |

## IIIF, full text, annotations, thumbnails

| File | What it taught |
|---|---|
| `iiif-manifest-api` README, `.../service/EdmManifestMappingV3.java`, `.../model/WebResourceSorter.java` | Manifest content, content-search service link, canvas order by next-in-sequence, thumbnails per canvas |
| `iiif-presentation-api` (listing) | Builds presentation resources for items, galleries and collections |
| `fulltext-api` README | Resources, annotation pages and annotations served as IIIF; search by issue |
| `annotation` README; `annotation-definitions/.../ModerationRecord.java`, `MotivationTypes.java` | Moderation record with endorse and report votes; motivations (highlighting, transcribing, tagging-related, commenting, and others) |
| `thumbnail-api` README | Object storage lookup order, no key, WebP generation |

## Recommenders, vectors, translation

| File | What it taught |
|---|---|
| `recommendation-api` README | Recommends similar records, sets or entities; uses a vector database, the embedding service, and the search API |
| `recommendations-updater` README; `.../common/MilvusConstants.java` | Batch job; 300-dimension vectors, L2 distance, about 60 million records need about 90 GB |
| `embedding-api` README; `python/README.txt`; `europeana_embeddings_cmd.py` | Multilingual text-embedding model plus dimension reduction |
| `vector-db-benchmark` README | Benchmarking vector engines |
| `api-image-similarity` README | Title only |
| `translation-api` README | "To be updated"; no detail |

## R&D repositories (READMEs)

`rd-img-classification-pilot`, `rd-img-tagging`, `rd-duplicate-detection`, `rd-watermark-detection`, `rd-img-superresolution`, `rd-img-utilities`, `rd-europeana-translate`, `rd-iiif-discovery-crawling`: purposes summarised in section 4.7 of the main document.

## Rights, contribution, operations

| Source | What it taught |
|---|---|
| `EuropeanaLicensingFramework`: `available-rights-statements.md` (and file list) | The 14 supported rights statements, addresses to use, what Europeana shows |
| `rightsstatements-data-model`: `README.md`, `InC_en.json` (and file list) | Statements are a SKOS vocabulary with label, definition, notes and scope note, in many languages |
| `statistics-dashboard-backend`: `.../model/StatisticsRecordModel.java`, `.../RightsCategory.java` | Dimensions measured; 14-way rights categories |
| `statistics-dashboard` README | Visualisation front end |
| `europeana-contribute`: README, `app/models/contribution.rb`, `app/models/ability.rb`, `app/models/cc/license.rb`, file list | Draft to published to deleted state machine; consent and takedown fields; roles; licence per contribution; OAI-PMH; Rails 5 on Mongo, Redis and S3 |
| `api-proxy-cache` README | Express proxy with Redis cache |
| `sea` README, package list (`packages/apps`: cats, ctf-apps, ds4ch) and the app READMEs | Monorepo of Europeana's other sites and Contentful tooling |
| Organisation repository list (220 public repositories, licences, last update) | Selection of repositories; no standalone DE-BIAS repository |

## Not read, and why

- `europeana.eu` pages: HTTP 403 for automated requests.
- pro.europeana.eu and Europeana's wiki: not fetched in this run (the code answered the questions).
- `entity-api-v2`, `entity-management`, `set-api`, `analytics-api`, `dataset-api`, `apikey`: only named in the main document from the repository list; internals not read.
- `europeana-blacklight` (archived 2019 Blacklight adapter for the Europeana API) is a possible Ruby reference but was not read; it targets old Blacklight.
- Google Arts & Culture: `https://artsandculture.google.com/` (home page, one fetch) and search results naming Google's blog posts: `blog.google/.../explore-art-and-culture-through-new-lens/`, `.../google-arts-culture-turns-10/`, `.../explore-art-and-color-our-latest-ar-gallery/`. Only the summaries returned by the search tool were seen for the blog posts.

## Rate limit

GitHub core limit started at 5,000 an hour with 4,984 remaining; this run used well under 5% of it (roughly 200 requests). The coordinator's note about a rate limit refers to the agent session, not GitHub.
