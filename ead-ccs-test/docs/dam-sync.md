# Syncing the Nexus DAM (Acquia DAM)

The record pages' images, and the rights that decide whether they are shown, come from the Nexus DAM (Acquia DAM, API v2 at
`api.widencollective.com`). The sync reads the DAM into the `dam_assets` table and writes the fields the app already reads into
a Solr core of its own. Images are linked from the DAM, not copied.

## What it does

- **Full** (`bin/rails dam:sync FULL=1`): reads every asset. It works through the DAM a month at a time by last edit date
  (a month with more than 5,000 assets is halved until each part has 5,000 or fewer), and saves the end of each finished part,
  so a run that stopped resumes there (`FRESH=1` starts again). About 70 minutes for 175,000 assets.
- **Why offset pages, not the DAM's scroll**: the DAM sometimes answers a scroll request with HTTP 500 *after* moving the
  scroll on, so a retry silently skips 100 assets (found on 2026-11-17: every retry lost exactly one page). An offset page
  ("assets 300 to 400, sorted by creation date") is the same however often it is asked for. Offset paging stops at 10,000,
  hence the halving. A part that returns fewer distinct assets than the DAM counted (an asset edited while it was read) is
  read again. The dev team's ingest (`api/src/ccs_api/acquia.py`) scrolls and retries, so it can lose pages the same way.
- **Incremental** (`DamSyncJob`, every 10 minutes): reads only the assets edited since the last run started, with 10 minutes
  of overlap. `bin/rails dam:sync` does the same by hand.
- **Reconcile** (`DamSyncJob`, Sundays 3 am Melbourne time): lists every asset id the DAM still has and marks the rest deleted.
  A run that sees fewer than 90% of the live assets marks nothing deleted. `bin/rails dam:reconcile` does the same by hand.
- **Report** (`bin/rails dam:report`): counts, and a CSV of the assets whose accession number matches no record.

Each run rewrites only the records whose DAM fields changed (a digest in `dam_digest_ssi`), as Solr atomic updates.

## Fields

| On the site | DAM field (display name) | Index |
|---|---|---|
| Accession number (the match) | `cAAccessionNumber` (CA Accession Number) | `accession_number_ssim` |
| Licence type | `dALicenseType` (DA License Type) | `digital_asset_metadata_ssm` → `AccessPolicy` |
| Advisory | `dAAdvisory1` (DA Advisory) | `digital_asset_metadata_ssm` |
| Terms of use | `dAAssetRights` (DA Terms of Use) | `digital_asset_metadata_ssm` |
| Producer | `dACreatorNameRole` (DA Creator Name (Role)): nearest field, to be confirmed by the dev team | `digital_asset_metadata_ssm` |
| Image order | `dAwebdisplaysequence` | order of the image fields |

**Each asset has its own licence and its own tier** (`AccessPolicy.asset_tiers`; the University agreed on 2026-11-18): an
asset is shown when its own DAM licence allows it, even if another asset of the same record is withheld. The EMu record-level
restrictions still withhold every asset of the record: an ICIP or restricted EMu licence, and the "Community Restricted" access
condition.

| What | Rule |
|---|---|
| An asset's tier | From its own DAM licence (`AccessPolicy::TIER_BY_DAM_LICENCE`); blank or "None" is `request` (withheld) |
| EMu ICIP / restricted licence, or "Community Restricted" | Every asset of the record is `request`, whatever the DAM says |
| Shown on the record page | The assets whose own tier is `open` or `view_only`; the page says how many others are withheld, with a request link |
| Offered to download | Only the assets whose own tier is `open` (`AccessPolicy.download_path?`) |
| `thumbnail_path_ssi`, `digital_asset_paths_ssim`, `digital_asset_large_paths_ssim`, `digital_media_ssim` | The viewable assets only, in display order: no address of a withheld asset is in the index |
| `digital_asset_download_paths_ssim` | The addresses (large image or original file) of the open assets |
| `digital_asset_metadata_ssm` | Every asset, withheld ones too, each with its `tier`, so the page can explain what is withheld |
| `has_digital_asset_bsi` | At least one asset is viewable (results sort these first; the **With Digital Asset** filter reads it) |
| `dam_access_tier_ssi` | The most permissive tier among the record's assets after the EMu restrictions (`AccessPolicy.tier`): `open` when at least one asset is open, `request` only when all are withheld |

It also writes `digital_asset_format_ssim` (the Format filter, for every asset). After a change to these rules,
`bin/rails dam:write` rewrites the fields from `dam_assets` without reading the DAM. When two records share an accession
number, an asset goes to the record of its own collection (`cACollection1`).

For searching it also writes `dam_licence_ssim` (the DAM licences, "None" and blank left out: the **License type** filter).
`dam_access_tier_ssi` feeds the **Digital asset Access Condition** filter, shown in the record page's own words, and the
**Open licence** switch, `FreeReuse`, which therefore means "has at least one open asset" (it falls back to the EMu licence only
for records without DAM data). The Pick of the day and the record's structured data use a record's picture only when that
image itself is an open asset (`AccessPolicy.first_image_open?`).

**Images**: the DAM's embed links (`unimelbourne.widen.net`), which do not expire. The preview links under `thumbnails`
(`widencdn.net`) are signed and expire after about a day, so they are not used and nothing needs refreshing at render time.

**Licences**: see `AccessPolicy::TIER_BY_DAM_LICENCE`. A blank licence withholds that asset ("request access"); on 2026-11-17
that was 96% of the DAM's assets. Before 2026-11-18 one withheld asset hid every asset of its record (only about 385 of 24,903
DAM-linked records were viewable); now a record shows its licensed assets and withholds only the rest.

## Running it locally

The token lives in the macOS Keychain (service `DAM_API_TOKEN`), never in a file. Store it once, in Terminal (a hidden prompt):

```
security add-generic-password -U -a "$USER" -s DAM_API_TOKEN -w
```

The sync's own core is a second Solr container on port 8985, a copy of the shared one (8984 is only read):

```
docker run -d --name ccs2027-dam-solr -p 8985:8983 --restart unless-stopped ccs2027-solr:latest \
  solr-precreate blacklight-core /opt/solr/server/solr/configsets/blacklight-conf
export DAM_SOLR_URL=http://127.0.0.1:8985/solr/blacklight-core
bin/rails dam:copy_index FROM=http://127.0.0.1:8984/solr/blacklight-core
DAM_API_TOKEN=$(security find-generic-password -a "$USER" -s DAM_API_TOKEN -w) bin/rails dam:sync FULL=1
```

Then run the site on that core, with the recurring jobs inside Puma:

```
DAM_API_TOKEN=$(security find-generic-password -a "$USER" -s DAM_API_TOKEN -w) \
SOLR_URL=$DAM_SOLR_URL SOLID_QUEUE_IN_PUMA=1 bin/rails server -p 3002
```

A new copy of the shared index (`dam:copy_index`) drops the DAM fields; run `dam:sync FULL=1` after it (it resumes nothing and
rewrites every record with an asset).

## Not done here

- Engineering and IT's 7,354 assets have no records in the index, so they match nothing.
- Hosting: the recurring jobs need a process that runs them (`SOLID_QUEUE_IN_PUMA=1` or `bin/jobs`) wherever the site is hosted.
