// `npm test`: runs every check in order and reports them all, instead of stopping at the first failure. The setup steps
// (lint, the Bootstrap build and its check) still stop the run, because the suites after them test what they build.
const { spawnSync } = require('child_process');

const SETUP = ['npm run lint', 'npm run build:css', 'npm run verify:bootstrap'];
const CHECKS = [
  'node tests/browser-available.test.js',
  'node scripts/sync-partials.js --check',
  'node tests/blacklight-adapter.test.js',
  'node tests/search-live.test.js',
  'node tests/catalog-api.test.js',
  'node tests/runtime-libs.test.js',
  'node tests/budgets.test.js',
  'node tests/page-integrity.test.js',
  'node tests/collection-data.test.js',
  'node tests/data-model.test.js',
  'node tests/workbook-drift.test.js',
  'node tests/no-inline-styles.test.js',
  'node tests/stylesheet-structure.test.js',
  'node tests/tokens.test.js',
  'node tests/advanced-filters.test.js',
  'node tests/combo-dropdowns.test.js',
  'node tests/advanced-link-chevrons.test.js',
  'node tests/smart-search.test.js',
  'node tests/search-bar.test.js',
  'node tests/search-history.test.js',
  'node tests/breadcrumb-home-icon.test.js',
  'node tests/results-filter-parity.test.js',
  'node tests/range-slider.test.js',
  'node tests/image-aspect.test.js',
  'node tests/style-diff.test.js',
  'node tests/pages-build.test.js',
  'node tests/accessibility.test.js',
  'node tests/modal-scroll-lock.test.js',
  'node tests/help-jump-nav.test.js'
];

function run(command) {
  console.log(`\n▶ ${command}`);
  const started = Date.now();
  const { status } = spawnSync(command, { shell: true, stdio: 'inherit' });
  return { command, ok: status === 0, seconds: ((Date.now() - started) / 1000).toFixed(1) };
}

const results = [];
for (const command of SETUP) {
  const result = run(command);
  results.push(result);
  if (!result.ok) break;
}
if (results.every((result) => result.ok)) CHECKS.forEach((command) => results.push(run(command)));

const failed = results.filter((result) => !result.ok);
console.log('\nSummary');
results.forEach((result) => console.log(`  ${result.ok ? 'pass' : 'FAIL'}  ${result.command}  (${result.seconds}s)`));
const skipped = SETUP.length + CHECKS.length - results.length;
console.log(`\n${results.length - failed.length} passed, ${failed.length} failed${skipped ? `, ${skipped} not run (a setup step failed)` : ''}`);
process.exit(failed.length ? 1 : 0);
