# Compliance register (CCS-148, BR-18.04)

Jira CCS-148: *"As the Nexus CCS, I want to comply with copyright law, rights-based access policies, and Indigenous data governance requirements so that all content is handled legally, ethically, and in alignment with cultural protocols."* The story has no acceptance criteria, so this register is the audit of what the application does today, what it cannot decide, and who has to decide it.

**This document is not legal advice and does not state what the law requires.** Where wording or a legal position is needed, the app carries clearly marked placeholder text for the University to approve (listed at the end). Last audited: 3 November 2026, on branch `nfr/compliance-ccs-148`.

## Summary for a non-technical reader

**What the site does now.**

- Every record page has a Copyright card. It shows the licence, the rights note and the credit line from the catalogue record, or says plainly that none is recorded. (Before this work, a record with none had no card at all, which could read as "no restriction".)
- Each record's digital file is handled by one of three rules, set from its licence: open (view and download), view-only (view, ask to download) or on request (not shown, ask to see). The rules are in one place (`AccessPolicy`) and are unchanged by this work. A request form collects a name, email and reason; staff act on the requests outside the site.
- Records marked Indigenous Cultural and Intellectual Property (ICIP) or Community Restricted are on request. Records noted as sensitive ask the visitor before showing their images. Records marked ICIP, Community Restricted or noted as culturally sensitive now also carry a **cultural protocols notice** that says why, and links to Help and the collection team.
- Bulk download and CSV export only ever include open records. Search engines are told not to index withheld or sensitive records, and AI crawlers are asked to keep out.
- A new **Accessibility** page (`/accessibility`) and **Privacy and data** page (`/privacy`) say what the site checks and what it stores. A new **Delete my data** page (`/my_data`, with saved records on) removes a visitor's saved records, lists, saved searches, search history and viewing choices.
- Security headers were checked. Two were added (a permissions policy and an opener policy), the form fields that hold a requester's personal details are kept out of the server logs, and every inline script now carries a CSP nonce so the content security policy can be switched from report-only to enforcing.

**What the site does not do.**

- It does not decide what the law requires, who owns what, or whether a licence is valid. It repeats what the catalogue record says.
- It does not check that the catalogue's licence, rights or ICIP fields are right or complete. About 31,000 of 40,962 records have no licence at all; the app treats them as view-only, never downloadable.
- It does not enforce the access rules on the image files themselves. The rules decide what the pages show; a file under `public/digital-assets` is served to anyone who has its address. Today only a few prototype images exist; the real digital asset system must apply the rules before real files are published.
- It has no approval screen, no staff sign-in and no email: access requests are exported by a command and actioned by people.
- It has no takedown or removal process, no record of consultation with communities, and no automatic removal of old guest data. These need people and policy first (CCS-112 is the related story).
- It has not been independently audited for accessibility, privacy or security.
- It does not show a cookie banner. The cookies it sets are needed for it to work; the University must confirm that no consent is needed (see decisions).

**Decisions the University must make** (the full list with owners is in section 6):

1. Approve, or replace, every placeholder wording listed in section 7.
2. Say who decides what happens to an ICIP or Community Restricted record, how a community or Elder is consulted, and how fast the University answers a request or complaint.
3. Decide which licence values are open, view-only or on request (today's table is the developers' reading of the data, not a University policy), and what the 31,000 records with no licence should be.
4. Decide how long guest data, search history, access requests and server logs are kept, and who may see access requests.
5. Confirm whether the cookies need a consent banner, and whether the University's own privacy and accessibility pages are enough or this site needs its own statements (the app links to both).
6. Decide the takedown route and who can remove a record or an image (CCS-112).
7. Decide whether the site will be audited against WCAG 2.2 AA, by whom, and when.

## 1. Copyright and rights display

| Area | How the app addresses it | Evidence | Gap | Owner | Status |
|---|---|---|---|---|---|
| Licence and rights on a record page | The Copyright card (`NexusCcs::RecordDocumentComponent`) shows caption, credit line, rights note, licence and responsible collection, and "About copyright and terms of use" linking to Help. With none recorded it says so (placeholder wording `nexus_ccs.rights.none_recorded`). The media viewer shows the licence chip and media metadata. | `test/integration/rights_display_test.rb` (one real record per licence value in the index, and records with none); `test/components/nexus_ccs/record_layout_test.rb`; `test/system/compliance_pages_test.rb` (axe) | The card repeats catalogue data; it cannot check it. The two stock comparison pages (`/stock`, `/branded-stock`) draw the licence badge only where the record has one, and exist for two records. | App (done); catalogue data: collection teams | Done in app; data open |
| Licence badges | `StockLicenceBadgeComponent` maps University values to a copyright symbol, Creative Commons values to CC icons and links. | `test/components` badge tests | Only used on the stock record pages. Hover text for CC with NC/ND and for the reproduction licence is missing "until the stakeholders decide". | University (wording) | Partial |
| `licence_type` and rights vocabulary | The index holds 9 University values plus 31,111 records with none (see `AccessPolicy`). The ingest takes `rights_ssim` from EMu related rights records and `credit_line_tsim` from `ObjCreditLine`; `access_condition_ssi` from `SecRecordStatus`. | `test/models/access_policy_test.rb` | The DAM's own classification (`dAUseStatus`, release and expiry dates) is not in the index yet. Rights expiry dates are not used. | Dev team (ingest); University (vocabulary) | Gap |
| Records with no licence | Treated as view-only (never downloadable) so images are not hidden for a data gap. | `AccessPolicy` tests | 31,111 of 40,962 records. Whether "unknown" should mean viewable is a policy call. | University | Decision needed |
| Terms of use / copyright help | Help has "Copyright and Terms of Use" (free access, licensed, cultural conditions, contact, Copyright Office). | `help.html.erb` | Wording is the content team's, not reviewed by the Copyright Office. | University | Open |
| Credit lines and attribution on downloads | The bulk download's `manifest.csv` and the record CSV carry licence, rights, credit line and persistent link. | `test/models/bulk_download_test.rb`, `record_csv_test.rb` | The files themselves are not stamped with a credit line. | Dev team | Open |
| Structured data and AI crawlers | `StructuredData` and `llms.txt` carry the licence where known; `llms.txt` has placeholder rights wording; `noai, noimageai` is on every page. | `seo_files_test.rb`, `seo_head_test.rb` | Only honoured by crawlers that choose to. Whether AI training is allowed is a University policy. | University | Decision needed |
| Orphan works, third-party content, moral rights | Not handled by the app. | None | Needs a University position and a field to hold it. | University | Not in app |

## 2. Rights-based access

| Area | How the app addresses it | Evidence | Gap | Owner | Status |
|---|---|---|---|---|---|
| Access tiers | `AccessPolicy`: `:open`, `:view_only`, `:request`, from licence and access condition; most restrictive licence wins. | `access_policy_test.rb` | The mapping is the developers' reading of the data. Not a University policy. | University | Decision needed |
| Notice and request flow | `AccessNoticeComponent` on view-only and on-request records; `/access_requests/new` form (name, email, organisation, reason), a confirmation only the requester's browser can open, rate limit of 5 an hour. | `access_requests_test.rb`, `access_request_test.rb`, system `access_request_test.rb` | No approval screen, no sign-in, no email, no service-level time. Staff use `bin/rails access_requests:export`. Approval changes nothing in the site. | University (process); dev team (screen) | Partial |
| Bulk download | Only open records, only files held on this server, limits of 25 records, 100 files, 200 MB; a plan is shown first; sensitive records skipped unless the visitor chose to view them. | `bulk_downloads_test.rb`, `bulk_download_test.rb` | Limits are placeholders. | University | Partial |
| CSV export | Only open records (404 otherwise); cells starting `= + - @` are neutralised. | `metadata_export_test.rb`, `csv_cell_test.rb` | Metadata of withheld records is still shown on the page (by design: metadata is shown on every tier). Whether metadata for ICIP records should also be restricted is a University decision. | University | Decision needed |
| Sensitivity gate | `Sensitivity` marks records whose restriction note says "sensitive"; the visitor is asked before assets show; the choice is kept in the cookie. | `sensitivity_test.rb`, `sensitivity_choices_test.rb` | Placeholder rule until the DAM advisory flag is available. A restriction note that says "sensitive" may mean medical, cultural or other: the gate does not say which. | Dev team; collection teams | Partial |
| Enforcement on files | None: hiding is done in the pages. Files in `public/digital-assets` are served by the web server to anyone with the address. A bot guard rate-limits and blocks listed crawlers. | `bot_guard_test.rb` | A withheld file that is on the server can be fetched by its address. Needs the real DAM (signed addresses or server-checked downloads) before real withheld files are published. | Dev team | Gap, high |
| Search engines | Withheld and sensitive records are `noindex` and left out of the sitemap; personal pages are `noindex, nofollow`. | `robots_policy_test.rb`, `sitemap_test.rb`, `personal_pages_robots_test.rb` | Search engines may already know addresses from elsewhere. | App | Done |

## 3. Indigenous data governance and cultural protocols

The relevant frameworks are named here so the University can say which it follows. The app does not claim to meet any of them.

- **ICIP**: Indigenous Cultural and Intellectual Property. The index has an `ICIP Rights` licence value on 29 records, which the app treats as on request.
- **CARE Principles for Indigenous Data Governance** (Collective benefit, Authority to control, Responsibility, Ethics).
- **AIATSIS Code of Ethics for Aboriginal and Torres Strait Islander Research**, and the AIATSIS guidance on collections.
- The University's own Indigenous strategy and protocols (Murmuk Djerring, linked from Help).

| Area | How the app addresses it | Evidence | Gap | Owner | Status |
|---|---|---|---|---|---|
| ICIP rights records | Licence `ICIP Rights` (29 records) puts the record on request; the record is `noindex`; the new cultural protocols notice says cultural protocols apply and links to Help and the collection team. | `access_policy_test.rb`; `cultural_protocols_notice_component_test.rb`; `rights_display_test.rb` | ICIP is held as a licence value. The data has no field for which community, who is the contact, or what conditions apply. The notice cannot say. | University with Indigenous advisers; dev team for fields | Partial |
| Community Restricted | `access_condition_ssi = Community Restricted` (1 record) is on request and shows the cultural protocols notice. | tests as above | As above. | University | Partial |
| Culturally sensitive images | Records whose restriction note says "culturally sensitive" get the sensitivity gate and the cultural protocols notice. | `cultural_protocols_notice_component_test.rb` | Detection is by the word "cultur" in a free-text note. The DAM's Indigeneity flag (CCS-55) has no source yet. | Collection teams; dev team | Gap: data |
| Indigenous names and terms | Help "Note on terminology" and "Note on language". The app shows names as the record holds them. | `help.html.erb` | No display rules (for example names of people who have died, Country names, language names with diacritics beyond the font). No Indigenous-names filter. | University with Indigenous advisers | Open |
| Deceased persons | Help has the note on names, images and voices of people who have died. `config/pages.yml` also holds an advisory for the Medical History Museum, which is not shown on any page now (collection pages redirect to results). | `help.html.erb`; `config/pages.yml` | No record is marked as showing a person who has died, and the Help note is not shown where the visitor meets the image. The Acknowledgement of Country is shown on the home page and in the footer. | University; dev team | Gap |
| Who decides | Not in the app. A request goes to the collection team; the team decides outside the site. | | Needs a written decision-maker per collection and per community, and a time limit. | University | Decision needed |
| Takedown and consultation | Not in the app. Help has a contact route. | | No process, form, log or record of consultation. CCS-112 is the separate story for removal. | University; CCS-112 | Not in app |
| Data sovereignty | Site data (guest data, requests) is in the University's Azure database; the catalogue is in the University's Solr. | `infra/azure/` | Where the Azure region is, and how that fits any community's data-sovereignty expectation, is a University decision. | University; dev team | Decision needed |
| Training AI on records | `noai` tags, `llms.txt` placeholder, listed crawlers blocked from assets. | `seo_files_test.rb` | Not a guarantee. | University | Decision needed |

## 4. Privacy (a checklist of questions, not a conclusion)

What the site stores, today:

| Data | Where | Personal? | Kept how long | Removed by |
|---|---|---|---|---|
| Session cookie `_ccs_session` (guest id, history ids, viewing choices, own request ids) | Browser | Pseudonymous | 30 days | Browser; Delete my data |
| `country_acknowledged` cookie | Browser | No | 1 day | Browser |
| `users` row (guest) | Database | Pseudonymous | Not limited | Delete my data |
| `bookmarks`, `lists`, `list_items`, `saved_searches` | Database | Pseudonymous | Not limited | Delete my data |
| `searches` (words and filters) | Database | Words a visitor typed can be personal | Not limited (`blacklight:delete_old_searches` exists but is not scheduled) | Delete my data (own history); otherwise nothing |
| `access_requests` (name, email, organisation, reason, record) | Database | Yes | Not limited | Not by Delete my data. By staff on request. |
| Web server logs | Azure | Addresses and pages | Azure's setting | Not by the app |
| `sessionStorage` (open filters, one page) | Browser | No | Tab | Browser |

The form fields of an access request (name, organisation, reason, email) are now filtered from the Rails log.

Questions for the University's privacy office, to answer before the privacy notice is approved:

1. Does the Australian Privacy Principles (APP) collection notice (APP 5) need to appear on the access request form? The form's "How we use your details" section (placeholder wording) now links to the privacy page.
2. Is a name and email on an access request "personal information" the University must be able to return, correct (APP 12, 13) or delete on request? Who handles that, and in what time?
3. Is there a purpose limitation on requests (staff may use the details only to answer the request)?
4. How long are access requests, searches and guest rows kept? Is deleting guest data after N days of no use acceptable?
5. Are search words personal information? Is the site's logged search text covered by the University's logging policy?
6. Where is the data held, and does any of it leave Australia (APP 8)? (Azure region, any CDN, the University search at `search.unimelb.edu.au` which receives the search words of that box only.)
7. Is a privacy impact assessment needed?
8. Who is the contact for privacy requests: the Help contact, or the University privacy office?
9. Does the University's data-breach plan cover this site?

Gaps found:

- No retention limit on guest rows, searches or access requests. A scheduled prune task is a small job once the University chooses the period.
- Delete my data is for a person's own browser only. A request for access to the person's details held in access requests goes to staff.
- Deleted guest data may remain in database backups. The backup period is an Azure setting.

## 5. Cookies, accessibility, records management, security, third parties

| Area | How the app addresses it | Evidence | Gap | Owner | Status |
|---|---|---|---|---|---|
| Cookies and consent | Two first-party cookies, both needed for the site to work as asked; no analytics or advertising cookies; no banner. The privacy page lists them. | `/privacy`; `content_security_policy_test.rb` | The University must confirm that no consent is needed, and decide whether University-wide analytics will be added (which would need a decision). | University | Decision needed |
| Accessibility statement | `/accessibility`: aim of WCAG 2.2 AA, how it is checked, known limits, how to report. Placeholder wording. Linked from the footer ("Accessibility of this site"). The University's own accessibility page stays as the primary "Accessibility" footer link, because it is the University's statement and applies to all its sites; this page adds what is specific to this site. | `compliance_pages_test.rb` | No conformance claim is made, and none can be until an audit. | University | Done; wording open |
| WCAG automated checks | axe-core 4.14, in a real browser, on: home, help, the old search tips, Indigenous data and contact addresses (which redirect to Help), advanced search, search results, a record page, the stock record pages in each state, the new pages and two record pages (ICIP and no-rights). The shared check runs the WCAG 2.0 and 2.1 A and AA rules. The new pages and two records also pass the WCAG 2.2 AA rules and axe best practices (`assert_accessible tags: AXE_TAGS + WCAG22_TAGS`). A one-off run of 2.2 and best practice over home, help and advanced search passed; search results showed one heading-order best-practice finding (an `h5` in a result card). | `test/system/accessibility_test.rb`, `compliance_pages_test.rb` | **Not tested**: screen reader use (NVDA, JAWS, VoiceOver); keyboard use beyond the focus tests; zoom to 400 and text spacing (a responsive test exists, not an axe rule); captions and transcripts for media; content in records (alt text from the catalogue); the image viewer for non-pointer users; the PDF and zip outputs; the access request form's error flow under a screen reader; and the other pages (lists, saved, history) under WCAG 2.2. Automated tools find roughly a third of problems. | University; dev team | Partial |
| Records management and takedown | None in the app. Records come from the University's source systems; a change there shows after the next ingest. Access requests are kept in the database. | | No retention schedule, no removal request form, no log of removals. Depends on CCS-112 (a separate story, not in this branch). A removal needs the source record, the Solr index, caches, sitemaps and search-engine copies handled. | University; CCS-112 | Not in app |
| Security headers | Present already: `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Permitted-Cross-Domain-Policies: none`, CSRF tokens, `HttpOnly` and `SameSite=Lax` cookies. Added: `Permissions-Policy` (camera, microphone, geolocation, payment, USB and others off; fullscreen and clipboard-write for self) and `Cross-Origin-Opener-Policy: same-origin` (`config/initializers/security_headers.rb`). HSTS comes from `RAILS_FORCE_SSL=true`, which the Azure deployment scripts set. | `security_headers_test.rb` | CSP is still report-only (see below). The session cookie is not marked `Secure` unless `force_ssl` is on. | Dev team | Partial |
| Content-Security-Policy | Report-only. Why not enforced: it has not been tried against every page in a browser with the console watched, and `style-src` still allows inline styles (Blacklight and the page markup set some). What changed: all five inline scripts in the layouts now carry the page's nonce, and a test fails if one does not. Enforcing is then one line (`content_security_policy_report_only = false`) after a pass over the pages. | `content_security_policy_test.rb`, `security_headers_test.rb` | A violation report address is not set; adding one would collect visitor addresses and needs the privacy decision. | Dev team | Partial |
| Third-party requests | Pages make **no** requests to other hosts when they load: fonts, scripts, styles, icons and charts are served by the site. Hosts that appear only as links a visitor chooses to follow: `www.unimelb.edu.au` and its subdomains (about, study, students, staff, research, library, giving, safety), `collections.mdhs.unimelb.edu.au`, `museumsandcollections.unimelb.edu.au`, `copyright.unimelb.edu.au`, `creativecommons.org` (licence links), `app.smartsheet.com` (a link in the page), and the social sites (`x.com`, `www.linkedin.com`, `www.instagram.com`, `www.facebook.com`) as footer links. The only form that sends data to another host is the University search box: it posts the typed words to `search.unimelb.edu.au`. | Audit of the rendered pages on 3 November 2026 | Nothing leaks by loading a page. The CSP `img-src` allows any HTTPS image so an external image in a catalogue field would load and tell its host the visitor's address: tighten once record images are known to be local. | Dev team | Done; one tightening open |
| Export and deletion of personal data | Delete my data (guest data) and the access-request note. | `my_data_test.rb`, `compliance_pages_test.rb` | A visitor cannot download their own data. Only an organisation-run request covers access requests. | University; dev team | Partial |

## 6. Decisions the University must make

| # | Decision | Owner |
|---|---|---|
| 1 | Approve or replace every placeholder in section 7 | Privacy office; Indigenous advisers; collection teams; content team |
| 2 | Who decides access to ICIP and Community Restricted records, and how a community or Elder is consulted | Collections with Indigenous advisers |
| 3 | The access tier for each licence value, and for records with no licence | Collections, Copyright Office |
| 4 | Time limits to answer an access request, a complaint or a takedown request | Collections |
| 5 | Retention periods: guest rows, searches, access requests, server logs | Privacy office, records management |
| 6 | Whether a cookie banner or analytics notice is needed | Privacy office |
| 7 | Whether the University's pages (primary footer links) are enough alongside this site's two pages | Web team |
| 8 | The takedown and removal process and who can remove (CCS-112) | Collections, records management |
| 9 | Accessibility audit and conformance claim | Accessibility team |
| 10 | Whether metadata of on-request and ICIP records may be shown and exported | Collections with Indigenous advisers |
| 11 | Position on AI training on records and images | Copyright Office, Collections |
| 12 | Data location and sovereignty | IT, Indigenous advisers |

## 7. Placeholder wording needing approval

| Where | What |
|---|---|
| `app/views/pages/accessibility.html.erb` | The whole page, including the marked notice, the WCAG 2.2 AA aim, and the reply time and complaint route. |
| `app/views/pages/privacy.html.erb` | The whole page, including cookie wording, retention (marked), logs (marked) and the access requests paragraph. |
| `app/views/my_data/show.html.erb` and `nexus_ccs.my_data` in `config/locales/en.yml` | Delete my data wording. |
| `nexus_ccs.cultural_protocols` in `config/locales/en.yml` | The cultural protocols notice (title, three reasons, link text). Needs Indigenous advisers. |
| `nexus_ccs.rights.none_recorded` in `config/locales/en.yml` | "No licence or rights statement is recorded for this record. Ask the collection team before you reuse it." |
| `config/locales/seo.en.yml` (`accessibility`, `privacy`) | Search-engine descriptions of the two new pages. |
| Already in the app before this work | `nexus_ccs.bulk_download` limits; `seo.llms_txt.rights`; the Sensitivity rule. |

## 8. Where things are

| Thing | File |
|---|---|
| Access tiers | `app/models/access_policy.rb` |
| Sensitivity | `app/models/sensitivity.rb` |
| Cultural protocols notice | `app/components/nexus_ccs/cultural_protocols_notice_component.rb` |
| Copyright card | `app/components/nexus_ccs/record_document_component.html.erb` |
| Accessibility and privacy pages | `app/views/pages/accessibility.html.erb`, `privacy.html.erb` |
| Delete my data | `app/controllers/my_data_controller.rb`, `app/models/my_data.rb`, `app/views/my_data/show.html.erb`; route `/my_data` inside the saved-records switch |
| Security headers | `config/initializers/security_headers.rb`, `content_security_policy.rb`, `filter_parameter_logging.rb` |
| Robots and sitemap | `app/models/robots_policy.rb` (`/my_data` is personal), `app/models/sitemap.rb` (the two new pages are listed) |
| Footer links | `app/components/nexus_ccs/site_navigation.rb` (`FOOTER_LEGAL`) |

Related: `docs/seo-and-bot-controls.md`, `docs/performance.md` (CCS-71), CCS-112 (removal, a separate story), CCS-55 (Indigenous data filter, no data source yet).
