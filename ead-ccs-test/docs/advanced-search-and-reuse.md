# Advanced search rules and the open-licence switch

## In plain language

**Rules.** On Advanced search each row is a rule: a field (all fields, title, creator, subject, description), a way to match
(contains, contains all of these words, contains this exact phrase, begins with, does not contain these words, has a value, is
empty) and some words. The "match all / any" menu joins the rules that include records. A "does not contain" rule always
leaves records out, whichever is chosen. "Add another rule" gives a field more than one rule (up to eight more), for example a
title that contains one word but not another. Without JavaScript the same button reloads the form with one more row.

**The switch.** "Open licence (public domain)" narrows any search to records whose licence lets a visitor view and download the
files (the "open" tier of `AccessPolicy`). It is a filter like any other: it shows as a pill, can be taken off, is kept in search
history and saved searches, and is counted in "Why am I seeing these results?". The wording is a placeholder: "free to reuse"
would be a legal claim, and the University has not approved one. A record can still have limits that are not in its licence
(moral rights, cultural protocols), so the switch says so and sends people to the Copyright and use section.

## Rule model

A rule is Blacklight's clause parameter, so old links keep working, with one new key:

| Parameter | Meaning |
|---|---|
| `clause[N][field]` | `all_fields`, `title`, `creator`, `subject`, `description` |
| `clause[N][query]` | the words |
| `clause[N][op]` | `must` / `should` / `must_not` (Blacklight's; the form's `op` menu is the default for every row) |
| `clause[N][match]` | NEW. Blank or `contains`: as before. `all`, `phrase`, `begins`, `not`, `present`, `empty` |

How each is sent to Solr (`app/models/advanced_rules.rb`, `AdvancedRules::SearchBuilderClauses`, in Solr's JSON query):

| match | Solr |
|---|---|
| contains (or none) | Blacklight's own: edismax with the row's field settings, the words as typed, so the search tips (AND, OR, quotes, + and -) apply |
| all | edismax, each word quoted and required: `+"skull" +"bone"` |
| phrase | edismax, one quoted phrase |
| not | `must_not` edismax of the quoted words with `mm=1` (any of them leaves the record out), whichever of all / any is chosen |
| begins | a `bool` of `prefix` queries on the string field (`title_si`, `creator_ssim`, `subject_ssim`), one per spelling (as typed, first capital, lower case, each word capitalised), the word as a JSON value. Not offered for description or all fields (no string field) |
| present / empty | a fixed Lucene range test on the field's text field (`title_tsim:[* TO *]`, `*:* -...`) |

Safety: in every match but "contains" the words are cut to 255 characters, everything but letters, digits, spaces and `'’.,&-` becomes a
space, and what is left is only ever sent inside quotes or as a JSON value. A match a field does not offer, or an unknown one,
is read as "all". At most 13 rules are read (the five fields and eight more). Tests: `test/models/advanced_rules_test.rb`.

Why all / any plus "does not contain" and not an AND / OR / NOT connector on each row: a mixed AND and OR list needs a precedence
rule visitors cannot see; this form is always unambiguous and maps directly to Solr's must / should / must_not. (Europeana's
query builder uses one connector per rule; the idea of rules of field + operator + term, and of add and remove buttons, is from
its `SearchQueryBuilder` and `SearchQueryBuilderRule` components. Nothing was copied.)

## The switch

`?f[free_reuse][]=open` (a query facet, `FreeReuse`, shown by `NexusCcs::FreeReuseSwitchComponent`; on Advanced search a checkbox
sends `f_inclusive[free_reuse][]=open`). The filter is built from `AccessPolicy.licences_with_tier(:open)` and
`AccessPolicy.withheld_access_conditions`:

- the record has an open licence, and
- it has no licence that is not an open one (a record with several licences gets the most restrictive tier, as `AccessPolicy.tier`),
  written as the Solr term ranges between the open values, and
- its access condition is not "Community Restricted".

Records with no licence are `:view_only`, so are not matched. When the DAM classification replaces `AccessPolicy.tier`, re-derive
`FreeReuse.filter_query`; `test/models/free_reuse_test.rb` checks against the core that every record it matches is `:open`.
It works with the default "With a digital asset" filter (both apply; today 62 records have both).

## Licence values, tiers and rights URIs

Counts are from the index when this was written. The URI column is the one `IiifManifest::RIGHTS_BY_LICENCE` already uses; the
others are **candidates for the University to decide**, not a decision.

| licence_type_ssim | Records | Tier | In the switch | Rights URI |
|---|---|---|---|---|
| Public domain - Copyright expired | 4,005 | open | yes | http://creativecommons.org/publicdomain/mark/1.0/ |
| Copyright - Current | 3,421 | view_only | no | http://rightsstatements.org/vocab/InC/1.0/ |
| Copyright | 587 | view_only | no | http://rightsstatements.org/vocab/InC/1.0/ |
| Reproduction Licence - Current | 1,760 | view_only | no | candidate: http://rightsstatements.org/vocab/InC/1.0/ (no URI today) |
| Reproduction Licence - Requested | 33 | view_only | no | candidate: InC, as above (no URI today) |
| Reproduction Licence - The University of Melbourne | 13 | view_only | no | candidate: InC, as above (no URI today) |
| Reproduction Licence - Restricted | 1 | request | no | none (no matching statement) |
| Restricted Access | 2 | request | no | none |
| ICIP Rights | 29 | request | no | none: needs a decision with the community |
| (no licence) | 31,111 | view_only | no | none |
| access condition Community Restricted | 1 | request | no (excluded) | none |

## How it maps to Europeana

Europeana's "Can I use it? Free reuse" filter is the API's `reusability` parameter: `open` (public domain marks, CC0 and the CC
licences that allow reuse with or without attribution and share-alike), `restricted` (other CC licences, such as non-commercial or
no-derivatives) and `permission` (in copyright, ask first). It is computed from each record's rights URI. Here the switch is
the `open` part: in the index only the public-domain licence qualifies. "Restricted" and "permission" have no equivalent yet: the
University's licences are not Creative Commons, so `view_only` and `request` stay separate and are not offered as filters. If the
records gain rights URIs, the switch could be derived from the URI (CC0, PDM and the CC BY family) in place of licence names.

## Files

New: `app/models/advanced_rules.rb`, `app/models/advanced_rules/`, `app/models/free_reuse.rb`, the `NexusCcs::AdvancedRule*`,
`AdvancedRulesComponent`, `AdvancedSearchFormComponent` and `FreeReuse*` components, `app/javascript/controllers/advanced_rules_controller.js`,
`app/assets/stylesheets/components/advanced_rules.css`, `config/locales/advanced_rules.en.yml`, `config/initializers/advanced_rules.rb`,
`app/views/catalog/_advanced_search_form.html.erb`. Edited (small): `SearchBuilder`, `SearchDefaults`, `SearchHighlighting`,
`SavedSearch`, `AccessPolicy` (two reader methods), `CatalogConfig::Facets`, `SearchDiagnosticsComponent`,
`_advanced_search_help.html.erb`, `application.css`, `data_model_test.rb`.
