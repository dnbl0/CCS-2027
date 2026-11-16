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

## Update 2026-11-16: the DAM usage rights decide

The index now carries each asset's DAM licence (`digital_asset_metadata_ssm`). `AccessPolicy.tier` reads it first: CC BY is
`:open`; All Rights reserved (UoM), Copyright Agency Limited and Individual are `:view_only`; a blank or "None" licence is
`:request` (the DAM has not cleared the asset, so it is not shown); a wording that says restricted or ICIP is `:request`. A record
with several assets gets the most restrictive. The EMu licence can only tighten the result to `:request`, never open it up, and
is the fallback when a record has no DAM usage rights at all. Open question for the University: confirm the mapping, in
particular that a blank DAM licence withholds the asset. The "open licence" filter (`FreeReuse`) still reads the EMu field until
the ingest indexes the DAM licence.
