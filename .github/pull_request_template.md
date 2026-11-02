## What changed and why

<!-- One or two sentences. Link the Jira story if there is one (CCS-123). -->

## Checks

- [ ] `bin/ci` passes in `ead-ccs-test/` (rubocop, erb_lint, brakeman, bundler-audit, locale and docs checks, tests with and without Solr); `bin/ci --system` if a page, script or style changed
- [ ] A test pins the new behaviour; a test that reads Solr calls `needs_solr`
- [ ] New sentences are in `config/locales/` and `ruby script/i18n_check.rb` passes
- [ ] A new environment variable is in `docs/configuration.md`; a new decision has an ADR in `docs/adr/`
- [ ] No new gem (or the team agreed, and the Gemfile says why), no secret, no personal data
- [ ] The branch name is not `feature/*`, `bugfix/*` or `enhance/*` unless I want it merged without waiting for CI (see CONTRIBUTING.md)

## Screenshots (for any visible change)

<!-- Desktop (1440px) and mobile (390px), before and after. Keyboard and screen reader behaviour if it changed. -->
