// Sitemap metadata: `lastmod` dates and hreflang alternates.
//
// @astrojs/sitemap runs outside the content-collection API, and its built-in
// `i18n` option assumes the locales share a URL shape (/x/ and /de/x/). Ours
// don't — /cancel/netflix/ pairs with /de/kuendigen/netflix/, and the German
// guide slugs are translated outright — so the pairing is read straight from
// the same frontmatter the pages use: `enSlug` on the German entries.
//
// Kept deliberately dumb: top-level scalar keys only, no YAML dependency.
// Nested blocks (the `faq:` array) are skipped because their keys are indented.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const CONTENT = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'src/content'
);

function readCollection(dir) {
  const base = path.join(CONTENT, dir);
  if (!fs.existsSync(base)) return [];

  return fs
    .readdirSync(base)
    .filter((file) => file.endsWith('.md'))
    .map((file) => {
      const raw = fs.readFileSync(path.join(base, file), 'utf8');
      const block = raw.match(/^---\r?\n([\s\S]*?)\r?\n---/);
      const data = {};

      for (const line of block ? block[1].split(/\r?\n/) : []) {
        const pair = line.match(/^(\w+):\s*(.+)$/);
        if (pair) data[pair[1]] = pair[2].trim().replace(/^['"]|['"]$/g, '');
      }

      return { id: file.replace(/\.md$/, ''), data };
    });
}

const collections = {
  guides: readCollection('guides'),
  cancel: readCollection('cancel'),
  guidesDe: readCollection('guides-de'),
  cancelDe: readCollection('cancel-de'),
};

/** Last meaningful edit to a page, as a W3C datetime. */
const lastmod = new Map();
/** hreflang sets, matching what the pages themselves emit in <head>. */
const alternates = new Map();

function record(pathname, entry) {
  const stamp = entry.data.updatedDate ?? entry.data.pubDate;
  if (stamp) lastmod.set(pathname, new Date(stamp).toISOString());
}

function pair(enPath, dePath) {
  const set = [
    { lang: 'en', url: enPath },
    { lang: 'de', url: dePath },
    { lang: 'x-default', url: enPath },
  ];
  alternates.set(enPath, set);
  alternates.set(dePath, set);
}

for (const entry of collections.guides) record(`/guides/${entry.id}/`, entry);
for (const entry of collections.cancel) record(`/cancel/${entry.id}/`, entry);

for (const entry of collections.guidesDe) {
  const self = `/de/guides/${entry.id}/`;
  record(self, entry);
  if (entry.data.enSlug) pair(`/guides/${entry.data.enSlug}/`, self);
}

for (const entry of collections.cancelDe) {
  const self = `/de/kuendigen/${entry.id}/`;
  record(self, entry);
  // Germany-only services (DAZN, iCloud+) have no twin and stay unpaired.
  if (entry.data.enSlug) pair(`/cancel/${entry.data.enSlug}/`, self);
}

// A hub is as fresh as the newest thing it lists.
function newest(entries) {
  const stamps = entries
    .map((entry) => entry.data.updatedDate ?? entry.data.pubDate)
    .filter(Boolean)
    .map((stamp) => new Date(stamp).getTime());
  return stamps.length ? new Date(Math.max(...stamps)).toISOString() : null;
}

for (const [pathname, entries] of [
  ['/guides/', collections.guides],
  ['/cancel/', collections.cancel],
  ['/de/guides/', collections.guidesDe],
  ['/de/kuendigen/', collections.cancelDe],
]) {
  const stamp = newest(entries);
  if (stamp) lastmod.set(pathname, stamp);
}

pair('/', '/de/');
pair('/guides/', '/de/guides/');
pair('/cancel/', '/de/kuendigen/');

/**
 * `serialize` hook for @astrojs/sitemap. Adds lastmod and hreflang alternates
 * to the entries we know about and leaves everything else untouched, so a new
 * page still lands in the sitemap without being registered here first.
 */
export function serializeSitemapEntry(item, site) {
  const pathname = new URL(item.url).pathname;

  const stamp = lastmod.get(pathname);
  if (stamp) item.lastmod = stamp;

  const set = alternates.get(pathname);
  if (set) {
    item.links = set.map((link) => ({
      lang: link.lang,
      url: new URL(link.url, site).href,
    }));
  }

  return item;
}
