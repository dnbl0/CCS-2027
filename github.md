repo: Enterprise-Services-Group/CCS-prototype-2026-v0.2
branch: main
path: (whole repo referenced for content only; no files copied)

## Last sync
date: 2026-09-28T15:18:29Z
commit: d27d12645c50

### Updated in this project
- Rebuilt the contact page (now `public/contact.html`; originally `Contact Us.dc.html`) using the real CONTACT_GROUPS / COLLECTION_CONTACTS data from script.js (MDHS/Vernon Collections: MHM, HFA, HBA emails; Museums & Collections: UAC, GMC external Smartsheet form)
- Added Bootstrap 5 for grid/card layout, layered with existing UoM Gen 3 tokens/typography/footer (now a local build; see BOOTSTRAP-DEPENDENCIES.md)

## Screen map
| Screen | Source files |
|---|---|
| `public/contact.html` (was Contact Us.dc.html) | script.js (CONTACT_GROUPS, COLLECTION_CONTACTS, renderContact, contactCardHTML) |

Note: this file records a one-off content sync from the source prototype repo (2026-09-28); it is not kept up to date. This repository's own GitHub remote is https://github.com/dnbl0/CCS-2027 (see README.md for CI and deployment).
