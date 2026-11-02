# Decoupling CCS 2027 from CCS 2026

## In plain language

CCS 2027 (the Rails app in `ead-ccs-test/`) started life as a copy of the 2026 project, which was a static prototype website. The two were tied together: every style change in 2027 had to match 2026, and a robot checked this on every change. That tie has been cut. 2027 now has its own repository name, its own checks and no link to the 2026 website. One thing remains: the old prototype files are still in this repository, because the 2027 app's page styles were copied from them and a few tools still read them. They do no harm, but they should be retired in a planned step (below).

## What was connected, and what was done

| Connection | Action |
|---|---|
| `parity` CI job and `scripts/parity.js` (compared Rails pages with the 2026 pages) | Removed, with `npm run parity` and the `public/**` and parity path triggers in `rails-ci.yml` |
| `pages.yml` (published the 2026 site to GitHub Pages, only for the 2026 repo) | Removed |
| `ci.yml` job `test` (tests the static prototype) | Kept, reduced: runs only when prototype files change, no longer on `ead-ccs-test/app/assets/**` |
| `npm test` check that the Rails style copies equal `public/` | Removed from `scripts/run-tests.js`, so Rails style edits no longer need a matching 2026 edit |
| Rails test comparing collection slugs with `public/collections/` | Removed |
| Repo names and URLs (README, docs, package.json, cloud-init, github.md, azure-deploy.yml comments, launch.json) | Now `dnbl0/CCS-2027` / `Enterprise-Services-Group/CCS-2027`; the 2026 handoff doc carries a "historical" note |
| `infra/azure/containerapps.sh` `MEDIA_BASE_URL` defaulted to the 2026 Pages site | Now required, no default. The app runs without it: `CCS_MEDIA_BASE_URL` falls back to `/digital-assets/media`, but then the audio, video and PDF links on the three records listed in `config/digital_media.yml` return 404 unless the files are served there. Deploying with the script now fails until a value is given. |
| `tests/pages-build.test.js` and `scripts/build-pages.js` used `/CCS-2026-MVP` as an example base path | Renamed to `/example-base` |

## Still coupled, and the next step for each

1. **Static prototype in `public/`, `src/`, `tests/`, `scripts/` (except the removed ones).** Kept: the Rails app's generated styles and images were made from it and `ead-ccs-test/lib/tasks/digital_assets.rake` reads `../public/assets/images/collections` by default. Next step: decide to archive the prototype (move to a separate archive repo), then delete these folders and `ci.yml`.
2. **Style generator `scripts/sync-rails-assets.js`.** Wrote `ead-ccs-test/app/assets/stylesheets/pages/*`, `tokens/static_site.css` and `images/site/`. Not run or checked by CI any more, but the files still say "Generated ... Edit the static file", and re-running it would overwrite 2027 edits. Next step: remove the header comments from those files, then delete the script (and `tests/stylesheet-structure.test.js`'s read of it).
3. **Root `package.json`.** The Rails system tests load axe-core from the root `node_modules` (`ead-ccs-test/test/application_system_test_case.rb`) and the `system` job runs `npm install` at the root, so `package.json` stays a Rails CI trigger. Next step: give `ead-ccs-test` its own package.json for axe-core.
4. **`digital_assets.rake` and `config/digital_assets.yml`** read the prototype's images and `collection-data.js`. Next step: move the source images into the Rails app or a storage location before deleting `public/`.
5. **Org/personal repo history and Azure.** Federated credentials and variables on Azure and GitHub still name whatever repo was set up; the comments now say CCS-2027, but the real settings were not touched. Next step: confirm they match `Enterprise-Services-Group/CCS-2027`.
6. **Historical text** in CHANGELOG, `docs/HANDOFF.md` and `docs/code-quality-plan.md` still describes 2026 repos; left as history.
