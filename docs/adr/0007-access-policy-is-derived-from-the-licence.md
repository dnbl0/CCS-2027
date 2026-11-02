# What a visitor may do with an asset is derived from the record's licence

`AccessPolicy` decides one of three tiers for each record (`:open`, `:view_only`, `:request`) from its `licence_type_ssim`
values, and from `access_condition_ssi` for the one value that withholds whatever the licence says (CCS-67, CCS-69). Metadata is
shown on every tier; only the asset is gated. A record with several licences gets the most restrictive tier, and a licence not
in the table is `:view_only` unless it says "restricted" or "ICIP". It is derived because the DAM's own classification is not in
the index yet (the University's ingest keeps it in the Solr field `assets_json`, and its real values are not known).

## Consequences

The rule lives in one place, `AccessPolicy.tier` with `TIER_BY_LICENCE` and `WITHHELD`; the record page, results cards, bulk
download, metadata export, structured data and sitemap only ask for the tier. When the DAM's classification arrives, replace
those rules and nothing else changes. Until then a blank licence (about three quarters of the records) is `:view_only`, so it
is never downloadable, but its images are not hidden for a gap in the data. `Sensitivity` is the same kind of stand-in for the
DAM's advisory. Both are tested directly (`test/models/access_policy_test.rb`, `sensitivity_test.rb`).
