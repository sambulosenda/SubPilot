// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import { serializeSitemapEntry } from './sitemap-meta.mjs';

// The one place the public origin is declared. Canonical URLs, OG tags, the
// JSON-LD block and sitemap.xml are all derived from it via `Astro.site`.
// Changing it also means updating the Sitemap line in public/robots.txt.
const SITE = 'https://subhelm.app';

export default defineConfig({
  site: SITE,
  integrations: [
    sitemap({
      serialize: (item) => serializeSitemapEntry(item, SITE),
    }),
  ],
  build: {
    inlineStylesheets: 'always',
  },
});
