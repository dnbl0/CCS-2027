# Scenario catalogue: home, browse, collection landing, about, contact, help, search tips, Indigenous data

Source: research agent, 2026-10-12 (code read only, app not run). Rails text lives in `ead-ccs-test/config/pages.yml`
(`app/models/site_pages.rb`). Static collection data is the `COPY`/`VISITS`/`BANNERS` dicts in
`src/collection-landing.template.html` (~lines 360-770), baked into 5 pages under `public/collections/<slug>/`.

## Cross-cutting facts
- No page shows a record count. Rails fetches `@counts`/`@named_counts` from Solr (`pages_controller.rb:12-15`) but no view uses them. Static filters "Total items" and "Date range" out of the details.
- All 5 collections have a banner image. There is no "no banner" variant. All 5 have `visit_url` and `website.url`.
- Landing layout is identical for all 5. Only the text varies.

## Per-collection differences (`pages.yml`)
| Collection | Advisory | Details and formats | Visitors box (sections) | Contact method | Explore further museum link |
|---|---|---|---|---|---|
| Grainger (GMC) | none | Grainger Museum; Instruments, Manuscripts, Correspondence | 4: Opening hours, Location, Getting here (6 long paragraphs), Accessibility (3) | none on the page | storeroom...grainger |
| Harry Brookes Allen (HBA) | "Contains medical/anatomical content advisory." | Dept of Anatomy and Physiology; Specimens, Models | 4: Visitors info (not open to public), Opening hours, Disability access (inline mailto), Location | `MDHS-museum@` inline | collections.mdhs.../explore |
| Dental (HFA) | "Contains medical content advisory." | Melbourne Dental School; Instruments, Equipment, Photographs | 5: Visitors info ("FREE admission"), Exhibition tours (mailto), Opening hours, Disability access (mailto), Location | `mhm-info@` inline | same URL as HBA and MHM |
| Medical History (MHM) | long Aboriginal and Torres Strait Islander "deceased persons" advisory (3 lines) | Faculty of Medicine, Dentistry and Health Sciences; Instruments, Models, Specimens | 3: Exhibition tours (mailto), Opening hours, Location (mailto) | `mhm-info@` | same URL as HBA and HFA |
| University Art (UAC) | none | Potter Museum of Art; Paintings, Sculpture, Works on paper | only 2: Visitors info (long, no hours or location), Collection access (link to `/contact` Access Request Form, fee note) | internal link to the Access Request Form | storeroom...art |

## Scenarios
| ID | Page | Scenario | Type | How reached | What the UI shows | Source | R/S |
|---|---|---|---|---|---|---|---|
| H1 | Home | Default | Happy | `/` | Hero ("Cultural Collections", search box, Parkville image), intro, 5 cards, 4 help cards, FAQ intro + 3 accordions | home.html.erb:4-115 | Both |
| H2 | Home | FAQ accordion collapsed vs open | Happy | click `details.ccs-acc` | Closed by default; open shows panel and 180 degree chevron; hover tint; focus ring | home.html.erb:90-110 | Both |
| H3 | Home | Acknowledgement of Country modal | Edge | first visit per day (cookie `country_acknowledged`, 1 day) | Dialog with title, quote, advisory, "Continue" button (autofocus). Home only | home.html.erb:117; country_acknowledgement.rb:12-34 | Rails only |
| H4 | Home | Restack at 1023 and 768 | Edge | narrow viewport | Hero, cards, help cards restack | static_shared.css:53-149 | Both |
| H5 | Home | Card focus, hover, long title | Edge | tab or hover | Whole card clickable via title link; focus ring on card; hover underlines title. Longest title "Harry Brookes Allen Museum of Anatomy and Pathology" | static_shared.css:108-110 | Both |
| B1 | Browse | Default | Happy | `/collections` | Breadcrumb Home > Browse collections + saved bar, dark banner with intro, 5 cards, "Help and guidance" with 3 pathfinder tiles | collections.html.erb | Both |
| B2 | Browse | Solr down | Sad | Solr unreachable | Identical page; counts swallowed and logged; counts never displayed | collection_counts.rb:25-27 | Rails |
| B3 | Browse | Card order | Edge | n/a | Alphabetical. `pages.yml browse.collections` (different order and blurbs, `tile-*` images) is unused | _browse_collections.html.erb | Rails |
| C1-C5 | Collection | Each of the 5 collections | Happy | `/collections/<slug>` | Breadcrumb Home > Browse collections > name; split campaign banner (h1, blurb, "Explore the collection" button to a collection-filtered search); About text; details table (3 rows); visitors box; "Explore further" 4 pathfinder tiles | collection.html.erb:1-71 | Both |
| C6 | Collection | Advisory present vs absent | Edge | GMC and UAC none; HBA, HFA, MHM have one | `notice--warning` paragraph under About; MHM's is 3 lines | collection.html.erb:26 | Both |
| C7 | Collection | Visitors box variants | Edge | see table | HFA 5 sections, UAC 2, GMC longest ("Getting here" paragraphs "Car:", "Train:"...) | pages.yml:90-117 | Both |
| C8 | Collection | Inline link types in box | Edge | HBA, HFA, MHM, UAC | mailto links; internal link to Access Request Form (UAC) | collection.html.erb:50 | Both |
| C9 | Collection | External links | Edge | n/a | "Full visitors information" opens new tab with sr-only "(opens in a new tab)"; 4th Explore tile `external: true` with new-tab icon | collection.html.erb:56,67 | Both |
| C10 | Collection | Unknown slug | Sad | `/collections/foo` | Rails RoutingError -> 404 page; slugs with digits or uppercase never match `[a-z-]+` | pages_controller.rb:18; routes.rb:28 | Rails |
| C11 | Collection | Unknown `?collection=` | Sad | `/collections/x/?collection=zzz` | Static falls back to the page's baked key (case-insensitive), silently swapping collection | collection-landing.template.html:739-741 | Static |
| C12 | Collection | Banner and mobile | Edge | <=1100 and <=768 | Split banner image and text stack; 4-column tiles collapse; contact aside drops below | static_shared.css:1200, 1137-1166 | Both |
| C13 | Collection | Banner button hover and focus | Edge | hover, focus-visible | Light background on hover; 3px white outline on focus | static_shared.css:1198-1199 | Both |
| A1 | About | Default | Happy | `/about` | Hero with h1 and image; link strip of 5 anchors; intro; Journey (dark, 3 steps, 2 links); Myer split; Support list + CTA; About the data (4 paragraphs); 5 cards; "Contact and support" | about.html.erb | Both |
| A2 | About | Anchor jump | Edge | link strip | Smooth scroll; no active state documented | help.css:113 | Both |
| A3 | About | Mobile | Edge | <=1000, <=768 | 2-column grids go to 1; hero padding changes; hero image min-height 220px | about.css:299-330 | Both |
| A4 | About | mailto | Edge | n/a | "Send feedback" `mailto:collections-navigator@unimelb.edu.au` | about.html.erb:104 | Both |
| T1 | Contact | Default | Happy | `/contact` | Banner; side "On this page" nav (4 links); MDHS group lists 3 emails (all `MDHS-museum@`); M&C group 2 "Access Request Form" links (external smartsheet, new tab) | contact.html.erb:18-31 | Both |
| T2 | Contact | General enquiries | Happy | n/a | Phone `tel:136352`, international `tel:+61390355511`, address, site-feedback mailto with italic note | contact.html.erb:34-42 | Both |
| T3 | Contact | "Before you get in touch" | Happy | n/a | 3-step ordered list + link to Access and information | contact.html.erb:44-52 | Both |
| T4 | Contact | Mobile | Edge | <=900 | Side nav stacks; left border and padding removed | contact.css:53 | Both |
| T5 | Contact | JS off or slow | Sad | static only | Rows are filled from JS data; raw `{{ c.name }}` / `{{ c.email }}` placeholders appear until the runtime runs | public/contact.html ~l.359-376 | Static |
| T6 | Contact | Access Request Form link | Edge | M&C rows | Both forms use the same smartsheet URL; collection name only in sr-only text | contact.html.erb:29-30 | Both |
| T7 | Contact | Email mismatch | Edge | data inconsistency | Contact page gives HFA and MHM `MDHS-museum@`; landing pages give `mhm-info@` | pages.yml:190,234 vs contact.html.erb:24-25 | Both |
| P1 | Help | All topics | Happy | `/help` | Banner; side nav "Help topics" with `aria-current` on "All help topics"; 5 sections stacked: FAQ (8 Q&As), Copyright (5), Access (contacts by group), Privacy (2); CTA band "Still need help?" | help.html.erb; _sections.html.erb | Both |
| P2 | Help | FAQ is not an accordion on /help | Edge | n/a | 8 FAQs are always-open `h3` + `p`; accordion only on Home | _sections.html.erb:7-39 | Both |
| P3 | Help | Old `?topic=key` links | Edge | `/help?topic=search-tips` | 301 to the topic page or `/help#key`; unknown topic renders `/help` | pages_controller.rb:23-26 | Rails |
| P4 | Help | Dead link in Access section | Sad | n/a | "Request Form: Open form" has `href="#"` | _sections.html.erb:95; public/help/index.html:330 | Both |
| P5 | Help | Anchored section | Edge | `/help#access` | Smooth scroll to the section | help.css:113 | Both |
| P6 | Help | Mobile | Edge | <=900 | Side nav stacks; topic grid 2 columns at 900, 1 at 560 | help.css:99-112 | Both |
| S1 | Search tips | Default | Happy | `/help/search-tips` | Breadcrumb Home > Help and support > Search Tips; banner; side nav (current = Search tips); long article with 2-column "dropdown option / searches" table, stemming, boolean; "Still need help?" contact box | search_tips.html.erb | Both |
| S2 | Search tips | Long content | Edge | n/a | Very long single article; backtick-quoted examples; 2-column group grid | search_tips.html.erb:21-27 | Both |
| I1 | Indigenous data | Default | Happy | `/help/indigenous-data` | Banner with long Acknowledgement paragraph; side nav (current = Indigenous); 2 links; warning notice "Note on images and voices"; language, terminology and contact notes | indigenous_data.html.erb | Both |
| I2 | Indigenous data | Link target mismatch | Edge | n/a | "Read about our Indigenous priorities" -> `/help#access`; static footer -> `unimelb.edu.au/reconciliation` | indigenous_data.html.erb:10 | Both |

## Components to check (code names)
Layout and chrome: `Header` / `ccs-nav--header`, `SiteFooter`, `PageBreadcrumbsComponent`, `SavedBarComponent`. Banners:
`PageBannerComponent`, `campaign-banner-split` (with `.button`), `ccs-hero`, `about-hero`. Home and listing: `ccs-section`,
`ccs-card(s)`, `ccs-help` card, `ccs-faq` + `ccs-acc` (details/summary accordion), `ccs-link`, `ct-link`, `ct-button`,
`ct-listing`, `PathfinderItemComponent` (`alt`, `external`), `grid--cols-3/4`. Content blocks: `link-strip`, `about-journey`,
`about-split`, `about-support`, `about-data`, `about-help`. Help and contact: `side-nav` (current), `help-layout`, `help-section`,
`cta-band`, `contact-box`, `def-table`, `notice notice--warning`, `help-search-tips`. Other: country acknowledgement
`dialog.modal`, `skip-link`.

## Rails vs Static differences
Daily Acknowledgement modal (Rails only); saved bar in breadcrumb strip (Rails only); Rails renders landing from YAML and 404s
unknown slugs, Static serves 5 baked pages with `?collection=KEY` fallback; banner markup differs (`section[aria-labelledby]` vs
`header[role=presentation]`); link conversion differs (sanitize vs JS markdown); card image paths differ; Static contact rows from
JS; Rails 301s `?topic=`; both have the dead `#` form link; Rails home card names do not match their link targets.
