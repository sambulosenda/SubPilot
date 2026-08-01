// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

// The one place the public origin is declared. Canonical URLs, OG tags, the
// JSON-LD block and sitemap.xml are all derived from it via `Astro.site`.
// TODO: replace once the domain is registered (see public/robots.txt).
export default defineConfig({
  site: 'https://subhelm.app',
  integrations: [sitemap()],
  build: {
    inlineStylesheets: 'always',
  },
});
