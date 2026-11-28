# Collections Navigator (Cultural Collections Search) - University of Melbourne

The product is the Rails/Blacklight app in `ead-ccs-test/`, searching the University of Melbourne's cultural collections. **New here? Read in this order:**

1. [ead-ccs-test/docs/running-the-app.md](ead-ccs-test/docs/running-the-app.md): run it on your computer (Ruby, PostgreSQL, Solr).
2. [docs/architecture.md](docs/architecture.md): how it fits together, and [CONTEXT.md](CONTEXT.md) for the words it uses.
3. [docs/how-to-change.md](docs/how-to-change.md): the usual changes, step by step.
4. [CONTRIBUTING.md](CONTRIBUTING.md): branches, tests and `bin/ci`.
5. [docs/configuration.md](docs/configuration.md) (every environment variable), [docs/adr](docs/adr/) (decisions) and [docs/maintainability.md](docs/maintainability.md) (the state of the code, and the backlog).

Rules for Claude agents working here: [CLAUDE.md](CLAUDE.md). Recent changes: [CHANGELOG.md](CHANGELOG.md).

**Design system**: UoM Gen 3 | **Hosting**: undecided (the Azure set-up is kept for when it is) | **Repository**: https://github.com/dnbl0/CCS-2027

> CCS 2027 is not connected to CCS 2026. The 2026 static prototype that used to sit in `public/`, `src/`, `scripts/` and `tests/`
> was removed on 27 Nov 2026 (the owner's decision; see [docs/decisions-2027.md](docs/decisions-2027.md), row 16). It is still in
> the git history. The Rails app's page styles were first copied from it and are now the app's own files.

## Repository layout

```
ead-ccs-test/               The Rails 8.1 + Blacklight 9 app (the product); its own README and docs/
docs/                       Architecture, decisions, ADRs, audits and handovers
data-model/                 The CCS field model (labels, filters, sequencing) taken from the field-label workbooks
assets/                     Source material for content: spreadsheets, CSVs, help and landing-page copy (.docx). Not deployed
scripts/museums-victoria/   Fetches Museums Victoria's stories about University objects and builds their records
infra/                      The Azure set-up, kept for when hosting is decided
package.json                Node tools the Rails app uses: axe-core (accessibility checks) and stylelint (its stylesheets)
```

## Checks

- `.github/workflows/rails-ci.yml`: the `rails` job (tests, rubocop, erb_lint, brakeman, docs and locale checks) and the
  `system` job (browser tests with axe-core against an indexed Solr core, and stylelint on the stylesheets). Both must pass
  on the latest commit before a pull request is merged. See [CONTRIBUTING.md](CONTRIBUTING.md) for running them locally.
- `npm install` at the repository root, then `npm run lint:rails-css`, lints the Rails stylesheets locally.

## Hosting

Hosting is undecided: the Azure set-up (`.github/workflows/acr-push.yml`, run by hand only, `azure-deploy.yml` and
`infra/azure/`) is kept for when it is.
