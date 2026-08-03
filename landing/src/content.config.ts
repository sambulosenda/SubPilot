import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

/**
 * Optional Q&A block. Rendered under the article body and emitted as FAQPage
 * JSON-LD, so each entry is a shot at a long-tail query the article itself
 * doesn't answer head-on. Keep answers self-contained: the schema strips them
 * out of their surrounding context.
 */
const faq = z
  .array(
    z.object({
      q: z.string(),
      a: z.string(),
    })
  )
  .optional();

const guides = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/guides' }),
  schema: z.object({
    title: z.string().max(70),
    description: z.string().max(160),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    faq,
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
    faq,
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
    faq,
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
    faq,
  }),
});

export const collections = { guides, cancel, guidesDe, cancelDe };
