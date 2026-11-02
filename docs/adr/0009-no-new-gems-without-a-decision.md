# Prefer Rails and the standard library: a new gem is a decision, not a convenience

Where a small amount of Ruby does the job, the app has it in the repository instead of a gem: the zip file for bulk download is
written with `Zlib` (`ZipWriter`, tested), citations are built in `Citation`, the sitemap, robots file and structured data are
generated (`Sitemap`, `RobotsTxt`, `StructuredData`), the rate limit is a small Rack middleware (`BotGuard`), the browser
tests drive Chrome through `cuprite`, and test coverage is measured with Ruby's own `Coverage` module (`bin/coverage`). The
gems in the Gemfile are Rails, Blacklight and its three plugins, the test and audit tools, and the drivers the platform needs.

## Consequences

Every dependency is something the University dev team must patch, audit (`bin/bundler-audit` runs in CI) and keep compatible
with Rails and Blacklight upgrades, so adding one is raised with the team first, with what it replaces and what it costs. The
price is a little more code to maintain, each with tests and a header comment saying what it decides. The Gemfile also holds gems
nothing uses today (jbuilder, kamal, image_processing, the solid_* adapters); removing them is on the backlog in
[docs/maintainability.md](../maintainability.md).
