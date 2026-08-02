import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const guides = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/guides' }),
  schema: z.object({
    title: z.string().max(70),
    description: z.string().max(160),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
  }),
});

const cancel = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/cancel' }),
  schema: z.object({
    title: z.string().max(70),
    description: z.string().max(160),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    /** Display name of the service, used on the hub page. */
    service: z.string(),
  }),
});

const guidesDe = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/guides-de' }),
  schema: z.object({
    title: z.string().max(70),
    description: z.string().max(160),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    /** id of the English twin, for hreflang pairing. */
    enSlug: z.string(),
  }),
});

const cancelDe = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/cancel-de' }),
  schema: z.object({
    title: z.string().max(70),
    description: z.string().max(160),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    service: z.string(),
    /** id of the English twin; absent for Germany-only services (DAZN). */
    enSlug: z.string().optional(),
  }),
});

export const collections = { guides, cancel, guidesDe, cancelDe };
