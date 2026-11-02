// Builds the static site for GitHub Pages into dist/.
//   BASE_PATH=/example-base node scripts/build-pages.js     (project site served under a sub-path)
//   node scripts/build-pages.js                              (served from the root, e.g. a custom domain)
//
// What this does for GitHub Pages, which has no server-side rules:
//  - root-absolute URLs ("/styles/x.css", '/help/index.html', url(/images/y.svg)) get the base path prefixed;
//  - /item/:code (a hosting rewrite) becomes a 404.html that forwards to the record page;
//  - the old *.dc.html and /search redirects in config/hosting.json become small meta-refresh pages;
//  - Pages has no /catalog.json function, so every page defaults the search adapter to its local catalogue.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const src = path.join(root, 'public');
const out = path.join(root, process.env.DIST_DIR || 'dist');
const BASE = (process.env.BASE_PATH || '').replace(/\/+$/, '');
if (BASE && !BASE.startsWith('/')) throw new Error('BASE_PATH must start with "/"');

fs.rmSync(out, { recursive: true, force: true });
fs.cpSync(src, out, { recursive: true });

// First path segments that belong to this site (top-level names with and without .html) plus the old API paths.
const names = new Set(['item', 'catalog', 'catalog.json']);
for (const n of fs.readdirSync(src)) { names.add(n); names.add(n.replace(/\.html$/, '')); }
const seg = [...names].map(n => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
// A quote, "(" or "=" directly before "/<known segment>" followed by a path/query/hash/quote end.
const absRe = new RegExp('(["\'`(=])\\/(?=(?:' + seg + ')(?:[\\/?#"\'`)\\s]|$|\\.(?:html|js|css|json|svg|png|jpe?g|webp|mp[34])))', 'g');
const homeRe = /((?:href|action)=")\/(?=")/g;

let rewritten = 0;
const rewrite = text => text.replace(absRe, (_, p) => { rewritten++; return p + BASE + '/'; }).replace(homeRe, (_, p) => { rewritten++; return p + BASE + '/'; });

const adapterDefault = '<script>window.CCS_CONFIG=Object.assign({apiMode:"mock"},window.CCS_CONFIG||{});</script>';
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);

for (const f of walk(out)) {
  const ext = path.extname(f);
  if (!['.html', '.css', '.js'].includes(ext) || f.includes(path.join('styles', 'vendor'))) continue;
  let text = fs.readFileSync(f, 'utf8');
  if (BASE) text = rewrite(text);
  if (ext === '.html') text = text.replace(/<head([^>]*)>/i, (m) => m + '\n' + adapterDefault);
  fs.writeFileSync(f, text);
}

// config/hosting.json redirects -> meta-refresh stubs (Pages cannot send 301s)
const stub = dest => `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>Redirecting</title><meta http-equiv="refresh" content="0; url=${dest}"><link rel="canonical" href="${dest}"><script>location.replace(${JSON.stringify(dest)} + location.search + location.hash);</script></head><body><a href="${dest}">Continue</a></body></html>\n`;
const cfg = JSON.parse(fs.readFileSync(path.join(root, 'config', 'hosting.json'), 'utf8'));
let stubs = 0;
for (const r of cfg.redirects || []) {
  if (r.source.includes('%')) continue; // the encoded duplicate of a source that has a literal space
  let rel = r.source.replace(/^\//, '');
  if (!path.extname(rel)) rel += '.html'; // /search -> search.html is served for /search
  const target = path.join(out, rel);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, stub(BASE + (r.destination === '/' ? '/' : r.destination)));
  stubs++;
}

// /item/:code -> record page; anything else is a plain not-found page
const notFound = `<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Page not found - Cultural Collections Search</title>
<script>
(function () {
  var base = ${JSON.stringify(BASE)};
  var m = location.pathname.slice(base.length).match(/^\\/item\\/([^\\/]+)\\/?$/);
  if (m) location.replace(base + '/collections/record.html?item=' + m[1] + location.hash);
})();
</script></head>
<body style="font-family:sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem">
<h1>Page not found</h1>
<p>We couldn't find that page. <a href="${BASE}/">Return to Cultural Collections Search</a>.</p>
</body></html>
`;
fs.writeFileSync(path.join(out, '404.html'), notFound);
fs.writeFileSync(path.join(out, '.nojekyll'), '');

console.log(`dist/ built: base "${BASE || '/'}", ${rewritten} URLs prefixed, ${stubs} redirect pages, 404.html`);
