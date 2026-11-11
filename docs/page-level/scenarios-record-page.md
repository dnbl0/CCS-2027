# Scenario catalogue: record (object) page

Source: research agent, 2026-10-12 (code read). Rails: `catalog#show` template (`show.html.erb`), body is
`NexusCcs::RecordDocumentComponent`. Static: `public/collections/record.html?id=N` (or `?item=CA-nn`), driven by `collection-data.js`.

> Rails layout changed again on 2026-11-11 (branch design/record-page-v2): a sub-navigation from 1200px; two columns, the viewer on the left
> (stage, round controls, strip of images, three short lines) and the record on the right (kicker, large title, byline, description, an
> access card with one primary button and quiet text actions); a centred 960px specifications column (Object details, Copyright and use,
> About this record); More like this without tabs. There is no title band, no Key facts and no toolbar. Rows below that name the title band,
> the Copyright card or the media band describe earlier layouts (and the static site). See ead-ccs-test/docs/styling.md, "The record page
> layout".

| ID | Page | Scenario | Type | How reached | What the UI shows | Source | R/S/B |
|---|---|---|---|---|---|---|---|
| R1 | Record | Full record, one image | Happy | `/catalog/:id` from results | Breadcrumb Home > "Search results" > title. Dark title band. Large image (alt = title). Toolbar with licence chip and "Media metadata" and "Full screen" buttons. Summary: title, creator and date, tags (format, collection), Save. "Details" ruled list. "Persistent link" card. "Copyright" card | record_document_component.html.erb:1-81 | Both |
| R2 | Record | Several images | Happy | as R1 | Thumbnail row under main image; click swaps the large image (modified click opens new tab). Alt "Title, image 2 of 3"; thumb alt ends "(opens full size in a new tab)". No JS: thumbs are links. Static instead: Previous/Next/First/Last, "x of N", a "Go to" select when more than 3 slides, thumbs strip | digital_assets_component.html.erb:51-62; record.html:300-325 | Both (different UI) |
| R3 | Record | No digital asset | Edge | records without `digital_asset_large_paths_ssim` | Rails: no media band, page starts at the summary. Static: viewer hidden, no "Web access" row | digital_assets_component.rb:20 | Both |
| R4 | Record | Video, audio, PDF | Happy | `digital_media_ssim` | Rails: `<video controls>` or `<audio controls>` with fallback "Download {label}"; PDF link "Open {label} (PDF, opens in a new tab)"; figcaption = label. Indexer does not yet index audio, video or PDF. Static: video, audio (icon + label), PDF iframe + "Open the PDF in a new tab" | digital_assets_component.html.erb:11-29 | Both |
| R5 | Record | Media fails to load | Sad | broken URL | Static only: "This media could not be loaded. Please try again later or contact the collection." (role=alert). Rails has no handler | record.html:280 | Static |
| R6 | Record | Media metadata panel | Edge | info button | Panel "Media metadata" rows "Licence type", "Advisory", "Terms of use". Advisory: "Some collection items include terms and views that are not appropriate today..." (same for every record with assets). Empty rows dropped; no rows = no button or panel. Esc closes. Full screen toggles "Full screen" / "Exit full screen", hidden if unsupported | digital_assets_component.rb:11,62; media_viewer_controller.js | Both |
| R7 | Record | Indigenous or deceased-persons advisory | Edge | static records flagged `advisories: ['deceased']` | Static: "Advisory: deceased persons" ("Aboriginal and Torres Strait Islander people should be aware that the University of Melbourne website and collections contain the names, images and voices of deceased people.") and "Advisory: language" in the metadata panel; related cards carry an `indigenous` flag. **Rails has only the generic advisory; no deceased-persons text, no Indigenous data notice on the record.** | collection-data.js:772-775,979-982 | Static (gap in Rails) |
| R8 | Record | Restricted view (gate) | Sad | static `viewRestricted` | Replaces the media. Title "This digital asset is available on request", access text, "Request to view" button. Rails has no gate | record.html:255-259 | Static |
| R9 | Record | View-only access note | Edge | static | "You can view this digital asset online. Downloading is available on request, with approval from the collection." + "Request to use" button. Copyright card "Web access": "View + Download", "View only" or "Request to view" | collection-data.js:976 | Static |
| R10 | Record | Request dialog | Happy/Edge | "Request to use" / "Request to view" | Dialog titles: Request to use, Request to view, Ask for more information, Request digitisation, Request physical access, Contribute information, Contact the collection. Fields Name, Email, Intended use. "Send request". Success "Thanks - your request has been recorded" (prototype disclaimer) | record.html:493-520 | Static |
| R11 | Record | Film/game classification | Edge | static `classification` | Copyright card shows rating logo or code, name, text (G, PG, M, MA 15+, R 18+, X 18+, CTC) | collection-data.js:776-783 | Static |
| R12 | Record | Missing or null fields | Edge | any | Rails `rows`: Title, then each configured field with a non-blank value, and "UoM ID" with Copy (always shown, before collection). Byline, tags and Copyright items omitted when empty; whole Copyright card omitted if no credit line, rights, licence or collection; licence chip becomes an empty span | record_document_component.rb:37-50,71 | Both |
| R13 | Record | Very long title, values, multivalued | Edge | any | One `record-details__value` span per value; byline max 2 creators joined with "; "; caption "Title. Date. Creator. Material. Copyright. Collection."; static wraps with `overflow-wrap:anywhere`; no truncation or "show more" anywhere | record_document_component.rb:24-28,65-69 | Both |
| R14 | Record | "View full record" | Happy | button in the persistent link footer | Dialog "You're leaving this site": "The full record for this item is held on {collection}'s own system, which the University of Melbourne doesn't maintain and isn't responsible for." Host line, "Stay on this page", "Continue to site" (new tab). Source falls back to "another organisation". URL is a hardcoded placeholder. Static: link "View in collection browser" | view_full_record_component.rb:11,41; en.yml:69-76 | Both |
| R15 | Record | Persistent link copy | Happy/Edge | "Copy link" | Label becomes "Copied" for 2s (static 1.8s), hidden status "Copied"; clipboard failure selects the input and falls back to execCommand. Note: "Quote the accession number {n} when contacting the collection team." or "Quote this link when contacting the collection team." Same Copy / Copied on the "UoM ID" row (aria "Copy UoM ID") | clipboard_controller.js; persistent_link_component.rb:20-22 | Both |
| R16 | Record | Save control | Happy | Save in summary (static: in the dark title band) | "Save" / "Saving..." / "Saved"; hidden suffix "record: {title}"; no-JS submit button; saved bar count updates | save_control_component.html.erb | Both |
| R17 | Record | Previous/next with search context | Happy | from a results list | Row above the footer: "Start over", "Back to Search", pager "Previous | n of N | Next". Appears only if the session `document_id` equals this record; Previous or Next is a span at the ends; N=1 shows "1 of 1" | document_header_component.html.erb | Rails |
| R18 | Record | Direct arrival, no search context | Edge | pasted persistent link | No pager; "Back to Search" and "Start over" only if a search session exists; breadcrumb "Search results" goes to the bare results page | header_component.rb:21 | Rails |
| R19 | Record | Breadcrumb | Edge | all | Desktop: Home icon > "Search results" > title (`aria-current`). Static also has mobile `bc-mobile` "< Search results". Rails BreadcrumbComponent has a collapsed back link but the record page uses HeaderComponent's own trail | header_component.rb:16-27 | Both |
| R20 | Record | Record not found | Sad | `/catalog/bogus` | Rails: `RecordNotFound` -> 404 -> stock `public/404.html` (not on brand; `blacklight.errors.invalid_solr_id` "Sorry, you have requested a record that doesn't exist." unused). Static: heading "No record matches this link"; "We could not find a record with that identifier. It may have been moved or removed, or the link may be incorrect."; links "Search the collections" and "Browse collections" | public/404.html:129; record.html:334-343 | Both |
| R21 | Record | Solr error | Sad | Solr down or timeout | HTTP 503 `catalog/unavailable`: "Search is unavailable", "We could not search the collections just now. Please try again in a few minutes.", links "Back to the home page" / "contact the collection team" (role=alert) | unavailable.html.erb | Rails |
| R22 | Record | Withdrawn or unavailable record | Edge | not built | No withdrawn, deaccessioned or restricted-record state exists in either. Would sit between R8 and R20 | n/a | none |
| R23 | Record | Mobile / tablet | Edge | <768px | Rails record_page.css breakpoints 768 and 1024; Copyright card beside details on desktop, stacked on mobile. Static: values stack under labels at <=768; media stage `min(62vh,440px)`; thumbs 64px; metadata sidebar becomes a bottom sheet (max-height 60%); gate padding smaller <=640 | record_page.css:136,175,399; record.css:1045-1131 | Both |
| R24 | Record | Related items / citation | Edge | static `showRelated`, `showCitation` | Default off. "Related items" cards with "View all {type} records". "Cite this item" tabs and "Copy citation" | record.html:396,461 | Static |

## Fields and when they show (Rails)
Same list for all five collections; a row shows only if non-blank. Order: Title (always), then Object type, production date,
creator (display), associated entity, production place, description (Vernon only), series, material (EMu only), cultural
group (2 records), accession number, named collection, collection (link to filtered search), classification, subject (EMu
only), parent record, related object; "UoM ID" with Copy sits before the collection. Rights and credit line live in the
Copyright card. Not yet mapped: editions, dimensions, inscription, language, physical access, source URL, child records.

## Components (code names)
Rails: `RecordDocumentComponent`, `DigitalAssetsComponent`, `RecordBannerComponent` (aria-hidden), `PersistentLinkComponent`,
`ViewFullRecordComponent`, `SaveControlComponent`, `DocumentHeaderComponent`, `HeaderComponent#breadcrumbs`, `SavedBarComponent`.
Stimulus: `clipboard`, `media-viewer`, `dialog`, `saved_bar`. Static: `ccs-save`, `ccs-licence`, `.item-media` (`im-*`), `.im-gate`.

## Rails vs Static
Static has: restricted gate, request dialog, deceased-persons advisory, classification ratings, richer media pager, a real
record-not-found message, optional citation and related items. Rails has: real prev/next with Start over / Back to Search,
persistent link card, UoM ID copy row, Media metadata panel, 503 handling, a generic unbranded 404.
