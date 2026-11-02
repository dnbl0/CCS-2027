// GitHub Pages build (scripts/build-pages.js): with a base path, every root-absolute URL is prefixed and every
// prefixed link resolves to a file in dist/ the way Pages would serve it; /item/:code and the old redirects exist.
const { fail, ok, walk, finish, fs, path } = require('./lib');
const { execFileSync } = require('child_process');

const BASE = '/example-base';
const root = path.join(__dirname, '..');
const dist = path.join(root, 'dist-test');
execFileSync('node', [path.join(root, 'scripts', 'build-pages.js')], { env: { ...process.env, BASE_PATH: BASE, DIST_DIR: 'dist-test' }, stdio: 'pipe' });

const resolves = u => { const f = path.join(dist, u); return [f, f + '.html', path.join(f, 'index.html')].some(x => fs.existsSync(x) && fs.statSync(x).isFile()); };
const files = walk(dist, p => /\.(html|css)$/.test(p) && !p.includes(path.join('styles', 'vendor')));
let unprefixed = 0, broken = 0, checked = 0;
for (const f of files) {
  const text = fs.readFileSync(f, 'utf8');
  const rel = path.relative(dist, f);
  for (const m of text.matchAll(/(?:href|src|action)="(\/[^"]*)"/g)) {
    if (m[1].startsWith('//') || m[1].includes('{{')) continue;
    if (!m[1].startsWith(BASE + '/')) { fail(`${rel}: root-absolute URL without the base path: ${m[1]}`); unprefixed++; }
  }
  for (const m of text.matchAll(/(?:(?:href|src|action)="|url\(['"]?)(\/example-base[^"')?#]*)/g)) {
    const u = decodeURIComponent(m[1].slice(BASE.length)) || '/';
    if (u.includes('{{')) continue;
    checked++;
    if (!resolves(u)) { fail(`${rel}: ${m[1]} does not resolve to a file`); broken++; }
  }
}
if (!unprefixed && !broken) ok(`${checked} prefixed links all resolve`);

for (const f of ['404.html', '.nojekyll', 'Contact Us.dc.html', 'search/advanced.html']) {
  if (fs.existsSync(path.join(dist, f))) ok(`dist has ${f}`); else fail(`dist is missing ${f}`);
}
if (/collections\/record\.html\?item=/.test(fs.readFileSync(path.join(dist, '404.html'), 'utf8'))) ok('404.html forwards /item/:code to the record page');
else fail('404.html does not forward /item/:code');
if (/apiMode:"mock"/.test(fs.readFileSync(path.join(dist, 'search', 'search-results.html'), 'utf8'))) ok('search page defaults the adapter to the local catalogue');
else fail('search page does not default the adapter to the local catalogue');

fs.rmSync(dist, { recursive: true, force: true });
finish('pages-build');
