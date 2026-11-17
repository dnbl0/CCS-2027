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

Each run rewrites only the records whose DAM fields changed (a digest in `dam_digest_ss`), as Solr atomic updates.

## Fields

| On the site | DAM field (display name) | Index |
|---|---|---|
| Accession number (the match) | `cAAccessionNumber` (CA Accession Number) | `accession_number_ssim` |
| Licence type | `dALicenseType` (DA License Type) | `digital_asset_metadata_ssm` → `AccessPolicy` |
| Advisory | `dAAdvisory1` (DA Advisory) | `digital_asset_metadata_ssm` |
| Terms of use | `dAAssetRights` (DA Terms of Use) | `digital_asset_metadata_ssm` |
| Producer | `dACreatorNameRole` (DA Creator Name (Role)): nearest field, to be confirmed by the dev team | `digital_asset_metadata_ssm` |
| Image order | `dAwebdisplaysequence` | order of the image fields |

It also writes `thumbnail_path_ssi`, `digital_asset_paths_ssim`, `digital_asset_large_paths_ssim`, `digital_media_ssim`
(audio, video, PDF), `has_digital_asset_bsi` and `digital_asset_format_ssim` (the Format filter). `has_digital_asset_bsi` is
true only when a visitor may see an asset (`AccessPolicy.view?`): results sort those records first and the "with images" filters
read it, so a record whose asset is withheld (a blank DAM licence) is not put first with nothing to show. After a change to
those rules, `bin/rails dam:write` rewrites the fields from `dam_assets` without reading the DAM. When two records share an
accession number, an asset goes to the record of its own collection (`cACollection1`).

**Images**: the DAM's embed links (`unimelbourne.widen.net`), which do not expire. The preview links under `thumbnails`
(`widencdn.net`) are signed and expire after about a day, so they are not used and nothing needs refreshing at render time.

**Licences**: see `AccessPolicy::TIER_BY_DAM_LICENCE`. A blank licence withholds the image ("request access"); on 2026-11-17
that was 96% of the DAM's assets, so most matched records still show no image until the licence is filled in at the DAM.

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

- The "Licence type" and "open licence" filters still read the EMu licence (`licence_type_ssim`, `FreeReuse`); the DAM licence
  is not a facet yet.
- Engineering and IT's 7,354 assets have no records in the index, so they match nothing.
- Hosting: the recurring jobs need a process that runs them (`SOLID_QUEUE_IN_PUMA=1` or `bin/jobs`) wherever the site is hosted.
