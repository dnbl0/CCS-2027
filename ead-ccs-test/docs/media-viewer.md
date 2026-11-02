# Media viewer, IIIF and compare (CCS-57, CCS-58)

## In plain language

A record's media are shown on its page by the kind of file. Images can be zoomed and panned, audio and video play in the
browser's own player, a PDF opens in a new tab, and a file the browser cannot show (a 3D model, say) says so instead of
vanishing. Every record with an image can be opened as an IIIF manifest, so tools such as Mirador and Universal Viewer can
read it. A visitor can compare images side by side: the images of one record, or records they have added from their pages.

None of this changes who may see what. Every new piece asks the same two questions the record page always asked:
`AccessPolicy` (a `:request` record shows no asset; a `:view_only` record can be viewed but not downloaded) and `Sensitivity`
(a sensitive record shows nothing until the visitor chooses to view it). Nothing of an image, not even its address, is in
the page, the manifest or the comparison until both say yes. `RecordMedia` is the one class the manifest and the comparison
use to ask; the record page's own component keeps its checks.

## How each media type is shown

| Kind | How | Notes |
|---|---|---|
| Image | The large image; **Zoom and pan** swaps it for an OpenSeadragon viewer | The viewer is loaded on first use (a dynamic import), so an ordinary page view costs nothing extra. Buttons Zoom in, Zoom out, Reset view; the viewer's canvas is focusable, arrow keys pan, `=` and `-` zoom, `0` resets. The mouse wheel does not zoom (it would trap page scrolling). Full screen is the media toolbar's button. Reduced motion turns the animation off. |
| Video | The browser's `<video controls>` | Keyboard and screen-reader support are the browser's. A `<track kind="captions">` is added when the record has a captions file. No download button unless the tier is `:open`. |
| Audio | The browser's `<audio controls>` | As video; a transcript link when the record has one. |
| PDF | A link that opens the file in a new tab | Only for `:open` records: a PDF cannot be read without being downloadable. An in-page reader would be a new dependency. |
| 3D model | "This 3D model cannot be previewed here", with a download link where the tier allows it | See "3D" below. |
| Anything else | The same cannot-be-previewed state | |

The mapping lives in `MediaTypes` (`app/models/media_types.rb`): format type (the DAM's `file_properties.format_type`), MIME
type or file extension, to a kind, and a kind to a viewer partial in `app/views/media_viewers/`. To add a viewer, add a partial
and name it in `MediaTypes::VIEWERS`.

## What needs a decision

**1. An image server (IIIF Image API).** The app serves static files from `public/digital-assets`; the IIIF Image API needs a
server (Cantaloupe, IIPImage, or the DAM's own). Without one the viewer loads the whole large JPEG, which is fine for the images
the site holds now but not for very large scans. The viewer is ready: when a record carries an IIIF info.json URL it is used as
the tile source, and the manifest names it as the image service. To use an image server on another host, add that host to
`connect_src` in `config/initializers/content_security_policy.rb` (info.json is fetched by script), and the server must send
CORS headers.

**2. The DAM field (CCS-315).** The index has no IIIF field yet. The name expected is defined once,
`MediaTypes::IIIF_INFO_FIELD = "iiif_info_urls_ssim"`: one info.json URL per large image, in the order of
`digital_asset_large_paths_ssim`, an empty string for an image without one. Change that constant when the DAM and the ingest
settle the name. The ingest also keeps `format_types_ssim` (each asset's `format_type`), which is not in the index; once it is,
`MediaTypes::FORMAT_TYPE_FIELD` is where to read it so that non-image files other than audio and video can be shown.

**3. A 3D viewer.** Neither `<model-viewer>` (Google's web component, glTF/GLB, AR on phones, built-in accessibility hooks) nor
three.js is in the app, and adding either is a new dependency, so it has not been done. The extension point is ready: `:model_3d`
is a known kind, with no viewer. To add one: pin the library, write `app/views/media_viewers/_model_3d.html.erb`, name it in
`MediaTypes::VIEWERS`, and check access (the file URL must stay out of the page unless `AccessPolicy` and `Sensitivity` allow
it, as the other partials do). `<model-viewer>` is the likelier fit: one element, keyboard orbit and zoom, `alt` text.
The DAM must also hold glTF/GLB files; the index does not list any now.

**4. Captions and transcripts.** Nothing in the DAM or the index carries them. The hooks: an entry in `config/digital_media.yml`
may have `captions` (a WebVTT file) and `transcript` (a text or HTML file), served from the same media base URL; they are stored
after the label in `digital_media_ssim` and the player partials use them. Where the real ones will come from (the DAM, a
vendor, the museum) is open. Audio and video with neither fail WCAG 1.2.1 to 1.2.3 for the people who need them, so this is a
content task to schedule, not a code one.

## The IIIF manifest

`GET /catalog/:id/manifest.json` returns an IIIF Presentation API 3.0 manifest (`IiifManifest`, `ManifestsController`):
one canvas per image, each with one painting annotation; labels as language maps; the record page as `homepage`; the
University as `provider`; the licence as `requiredStatement` always, and as `rights` when it maps to a Creative Commons or
RightsStatements.org URI (public domain: CC Public Domain Mark; copyright: In Copyright; the other licences have no URI).

- `:open` and `:view_only` records only. A `:request` record, a sensitive record the visitor has not chosen to view, and a record
  with no image whose size can be read, give a 404 with nothing of the record in the body. An image whose size cannot be read
  (only `.jpg` and `.png` files under `public` are measured) is left out, as a canvas needs a size.
- `:view_only` records are listed because their images can be viewed; the manifest points to the same files the page does. The
  image files are public static files, so "no download" is a browser-level courtesy on this site, not a protection.
- Cache and CORS. An ordinary manifest is the same for everyone: `Cache-Control: public, max-age=3600`, and
  `Access-Control-Allow-Origin: *` so a viewer on another site can read it (the IIIF spec's recommendation). A sensitive record the
  visitor chose to view depends on their session cookie: `private, no-store` and no CORS header (another origin sends no cookie
  and would get the 404).
- The manifest is `noindex, nofollow` and disallowed in robots.txt.
- Audio, video and PDF are not in the manifest (the story is about images).

## Compare

- **One record's images:** `/compare?record=ID`, two panes (`&panes=3` or `4`, no more than the record has images). The record page
  offers **Compare images** when it has more than one.
- **Several records:** **Add to compare** on the record page (session only, at most four, stored as ids in the session cookie);
  `/compare` lists them. A record can be added only when its images may be shown to this visitor; the check is repeated each time
  the page is drawn, so a record that is later hidden or withheld drops out with a note and its image is never drawn.
- Each pane has its title (a link to the record), accession number and licence, a selector for the image when the record has
  several, and Zoom in, Zoom out, Reset view and Full screen buttons. **Link zoom and pan** (on by default) makes the panes move
  together. The panes stack under 48rem, hold their size before the viewers start (no layout shift), and Escape leaves full
  screen (the browser's own behaviour). Without JavaScript each pane is the plain image and the controls stay invisible.
- `/compare` is a personal page: `noindex, nofollow`, listed in `RobotsPolicy::PERSONAL_PREFIXES`, with its own `PageChrome` entry.

## Accessibility notes

Controls are real buttons with visible text names (so the accessible name is the visible label), at least 44px high, with a
visible focus ring. The viewer's canvas has `role="group"` and a label with the image's text alternative and the key hints.
`aria-pressed` on the Zoom and pan toggle; focus moves into the viewer when it opens and back to the toggle when it closes.
The system tests (`test/system/media_viewer_test.rb`) run axe on the record page with zoom on and on the comparison page at
desktop and 320px widths.
