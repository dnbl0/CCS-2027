# Contributing

How to change Collections Navigator (the Rails app in `ead-ccs-test/`) and get the change reviewed. Start with
[docs/architecture.md](docs/architecture.md) to see how it fits together and [docs/how-to-change.md](docs/how-to-change.md) for
the usual changes. Running the app on your computer is in [ead-ccs-test/docs/running-the-app.md](ead-ccs-test/docs/running-the-app.md).

## Branches and pull requests

- Branch from `main`, one change per branch, named for the change: `fix/results-count`, `docs/architecture`, `nfr/maintainability`.
- Commit messages are Conventional Commits (`fix:`, `feat:`, `docs:`, `test:`, `chore:`, `perf:`) with the Jira key at the end of the
  first line, for example `fix: the lists page's Saved records link used a missing key (CCS-149)`. Say why, not only what.
- Open a pull request into `main` using the template. A person reviews it; a Rails change is never merged automatically.
- Keep a pull request small enough to review in one sitting. Move code or reformat in its own commit, apart from a behaviour change.
- No secrets in files, messages or pull requests. Production values are Azure secrets.

### The auto-merge trap

`.github/workflows/auto-merge.yml` runs on a push to any branch named `feature/**`, `bugfix/**` or `enhance/**` that changes a
`.md`, `.css`, `.js` or `.html` file outside `ead-ccs-test/`, and then, for 3 or more commits or 2 or more changed files, **opens a
pull request and squash-merges it into `main` straight away, without waiting for the Rails checks.** A documentation change that
rides along with a Rails change on such a branch is enough. To avoid it, use another prefix (`fix/`, `docs/`, `nfr/`, `chore/`)
unless you want that behaviour. Check the branch name before the first push; a merge cannot be taken back by renaming the branch.

## Before you push

Run what GitHub runs:

```sh
cd ead-ccs-test
export SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core     # your development Solr, see docs/solr-dev.md
bin/ci                # rubocop, erb_lint, brakeman, bundler-audit, importmap audit, locale and docs checks,
                      # then the tests without Solr (as GitHub's "rails" job) and with it
bin/ci --system       # also the browser and accessibility tests (needs Solr with records indexed and Chrome)
bin/ci --quick        # skips the audits, which fetch advisory data from the network
```

`bin/ci` stops reporting green only if every step passes. The checks are the ones in `.github/workflows/rails-ci.yml`; the
`system` job there runs `bin/rails test:system` against a real Solr.

## Tests

- `bin/rails test` runs everything except the browser tests (`test/system`), about 640 tests in 12 seconds. A single file:
  `bin/rails test test/models/access_policy_test.rb`; a single test: add `:LINE`.
- **Tests that read Solr must call `needs_solr`** (`test/test_helper.rb`) in `setup` or at the top of the test. GitHub's `rails`
  job has no Solr, so such a test skips there and runs in the `system` job. A test that reads Solr without it fails in CI.
- **System tests run one process at a time**: `PARALLEL_WORKERS=1 bin/rails test test/system/search_journeys_test.rb`, one file
  at a time. They share one browser and one session store, and parallel runs interfere.
- **A second checkout or worktree needs its own databases**: `export DB_SUFFIX=_2`, then `bin/rails db:prepare` and
  `RAILS_ENV=test bin/rails db:prepare`. Without it two checkouts truncate each other's test database mid-run.
- **A skipped test must still clean up.** `skip` (and so `needs_solr`) raises, and the lines after it never run. Anything that
  changes global state (an environment variable, a `Rails.configuration.x` setting, a file) is put back in `teardown` or an
  `ensure`, or by a helper that does it, such as `with_env` (`test/support/env_override.rb`); never in a line after the code that
  might skip. Call `needs_solr` first, before the state changes.
- Pin behaviour with a test before you change it, and name the test for what the visitor sees, not the method.
- Coverage: `bin/coverage` prints line coverage by directory (no gem). It is a guide, not a target: see
  [docs/maintainability.md](docs/maintainability.md).

## Style

- `bin/rubocop` (Rails omakase) and `bin/erb_lint --lint-all` must pass. Do not loosen a rule to get past one; fix the code or
  disable the single cop on the single line with a reason.
- Match the file you are in: comments say what a thing decides and why, in Australian English (colour, organisation, licence for the
  noun, catalogue). Every model starts with a comment saying what it decides, as the existing ones do.
- Every sentence a visitor reads is in `config/locales/` ([how-to-change.md](docs/how-to-change.md#add-a-locale-string)). Run
  `ruby script/i18n_check.rb`.
- New environment variables go in [docs/configuration.md](docs/configuration.md) in the same change (`ruby script/check_docs.rb`).
- No new gems without the team's agreement ([ADR 0009](docs/adr/0009-no-new-gems-without-a-decision.md)).
- Accessibility is part of done: keyboard, focus, headings, contrast and the axe checks (`test/system/accessibility_test.rb`).

## Decisions

A decision that would be undone by accident (a default, a boundary, a policy) gets a short record in [docs/adr](docs/adr/): what
was decided, then "Consequences". The words the product uses are in [CONTEXT.md](CONTEXT.md).
