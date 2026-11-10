# A replaced media file shows without a manual purge (CCS-425)

> As a Collection Manager, I want a digital asset media file to be refreshed in CCS when a file is replaced in the Nexus DAM with
> an updated version using the same filename, so corrected versions (for example an image orientation fix) are displayed in CCS
> without manual intervention.

## In plain language

**Solved in the app:** once a replaced file is in the folder this server serves (`public/digital-assets`), visitors see the new
version without anyone purging a cache. Before, a file replaced under the same name stayed in visitors' browsers for up to a day
(and the image size the page had recorded for it was never read again). Now every page that shows a media file gives its address
a token that changes when the file does, and the server says "unchanged" or sends the new file when a browser asks.

**Not solved here, and needs the DAM or indexer team:** nothing in this app notices that a file was replaced *in the DAM*. The
sample images are copied into `public/digital-assets` by hand or by script (`config/digital_assets.yml`), and the Solr index
carries no modified date or checksum for a file. Whoever puts the new file into that folder (or onto the media host) is the
step that makes it reach CCS. See "What needs the DAM or indexer team" below.

## How it works

| Where | What changed | Code |
|---|---|---|
| Every address of an image or media file on a page: results cards and mosaic, record cards (related, similar, recently viewed), the record page's image, thumbnails and viewer sources, video, audio and PDF links with their captions and transcripts, the zoom viewer, the stock embed viewer, embed pages, oEmbed `thumbnail_url`, the comparison page, the IIIF manifest and its thumbnail, the JSON-LD `image` | The address ends in `?v=<token>`; the token is the file's modified time and size, so replacing the file changes the address. A new address is a new fetch: browsers, proxies and a CDN have never seen it | `AssetVersion` (`app/models/asset_version.rb`), used by `RecordMedia`, `SharedMedia`, `StructuredData`, `NexusCcs::ResultCardComponent`, `NexusCcs::RecordCardComponent`, `NexusCcs::DigitalAssetsComponent`, `StockOpenseadragonEmbedComponent` |
| `/digital-assets/...` files at an address with a token | `Cache-Control: public, max-age=31536000, immutable`. Safe, because the address changes with the file | `StaticCacheControl` |
| `/digital-assets/...` files at any other address (an old link, another site's embed, a cached page from before) | `Cache-Control: public, max-age=0, must-revalidate`. The browser asks each time; Rails' static file server answers `304 Not Modified` (ETag or Last-Modified) while the file is the same and sends the new file when it is not | `StaticCacheControl`, `ActionDispatch::Static` |
| The image's width and height (kept so the page does not jump while the image loads) | Read again when the file's modified time or size changes. Before, the size was kept for the life of the process: an orientation fix swaps width and height, so the page would have drawn the new image in the old shape | `lib/image_dimensions.rb` |
| IIIF manifest | `Cache-Control: public, max-age=0, must-revalidate` with an ETag, so a repeat request is a 304 while nothing changed (before: public for an hour, so a stale manifest could name an old image for up to an hour). Still open to other origins; a sensitive record the visitor chose to view is still `private, no-store` | `ManifestsController` |
| Downloads (the bulk zip, the single-file links) | Nothing to change: the zip reads the file from disk when asked, and a single-file link is a versioned address like the others | `BulkDownload` |

The token is read from the file's modified time and size, kept in memory for 10 seconds per file (`AssetVersion::CHECK_EVERY`), so
a results page of 20 thumbnails costs at most 20 `stat` calls the first time and none for the next 10 seconds. It adds no Solr
request and no database query; `PerformanceTest` still holds. A replaced file therefore shows after at most 10 seconds (per
server process) on the next load of the page. A page a visitor already has open keeps the old image until it is loaded again; the
HTML is never publicly cached.

### What it does not change

- **Access.** The token is added only where the page already decided the asset may be shown (`AccessPolicy`, `Sensitivity`). A
  withheld (`:request`) record, and a sensitive record the visitor has not chosen to view, still show no asset path at all, tokened
  or not, in the page, the manifest, the embed, oEmbed or the comparison. `MediaRefreshTest` checks it.
- A file that is not on this server, or not there yet, has no token and its address is unchanged.
- Robots: `/digital-assets/` is still `noindex` and disallowed; a `?v=` address is the same path.
- The mosaic and list placeholders (SVG in `app/assets`) are fingerprinted by Propshaft and need nothing.

## What needs the DAM or indexer team

Plainly: the app can only react to a file *it can see change*. These are the gaps, in order of how much they would help.

1. **Getting the replaced file into CCS.** Today a file reaches `public/digital-assets` by the project's own script. When the DAM
   replaces a file, the ingest (or a sync job) must copy the new file over the old one, under the same name. Until it does,
   CCS has nothing to show. In production the same applies to the host named by `CCS_MEDIA_BASE_URL` and to any IIIF image server.
2. **A modified date or checksum per file in the feed and the index.** A field parallel to `digital_asset_large_paths_ssim` (for
   example one value per image: the DAM's `modified` timestamp or the file's SHA-256) would let the app build the token from the
   DAM's own statement of "this is a new version", not from a file's time on this server, and would work for files on another host
   (`CCS_MEDIA_BASE_URL`, the IIIF image server), which the app cannot stat. It would also say that the metadata was re-indexed.
   Adding it is an index schema change and an indexer change; it was **not** done here, and the shared Solr was not touched. The
   change in the app is small: pass that value to `AssetVersion.url` in place of the file's modified time.
3. **A re-index of the record when its file is replaced**, if the thumbnail path or the image count changes with it. The same-name
   case in the story needs no re-index here, because the address in the index does not change.
4. **Derived images.** CCS shows an 800 px thumbnail and a 1600 px large image (`public/digital-assets/thumbs`, `large`). If they
   are made from the DAM original by a script, that script must run again for the replaced file; replacing only the original
   changes neither.
5. **A CDN or reverse proxy, if one is added.** It must pass the query string through to the cache key (the token is in it) and
   must not rewrite `Cache-Control` for `/digital-assets/`. A purge is then never needed for a tokened address.
6. **The IIIF Image API server, when there is one** (see [media-viewer.md](media-viewer.md)). Its tiles and `info.json` are on
   its own host; its own caching and cache-busting (or a version in its identifier) are its team's, and the same checksum field
   is what would drive them.

## Checking it by hand

1. Note an image's address on a record page: `/digital-assets/large/<name>.jpg?v=<token>`.
2. Replace `public/digital-assets/large/<name>.jpg` with a different file of the same name.
3. Reload the record page after 10 seconds: the token has changed and the new image shows, with no hard refresh and no purge. The
   old address, if opened directly, is revalidated and also answers with the new file.

## Tests

`test/models/asset_version_test.rb` (the token, the 10-second look, what is left alone), `test/lib/image_dimensions_test.rb` (the
size follows a replaced file), `test/integration/media_refresh_test.rb` (304 and validators, the manifest, embeds, oEmbed, compare,
results, and that withheld records show no path) and `test/integration/performance_test.rb` (cache lifetimes by kind of file).
