export const SITE_NAME = 'SubHelm';

export const AUTHOR_NAME = 'Sambulo Senda';

/**
 * Profile URLs for the author entity in JSON-LD. Google leans on these to tie
 * the byline to a real, findable person, which matters on money-adjacent
 * content. Empty means the `sameAs` property is omitted rather than emitted
 * blank — add GitHub / X / LinkedIn here.
 */
export const AUTHOR_SAME_AS: string[] = [];

/**
 * Stable JSON-LD node ids, resolved against `Astro.site`. Base.astro defines
 * these nodes on every page; everything else references them by id so the
 * bylines, the app listing and the site collapse into one entity in Google's
 * graph rather than a dozen unrelated copies.
 */
export const SCHEMA_ID = {
  organization: '#organization',
  author: '#author',
  website: '#website',
} as const;

export const APP_STORE_URL =
  'https://apps.apple.com/us/app/subhelm-subscription-tracker/id6777939621';

export const SUPPORT_EMAIL = 'sambulosendas@gmail.com';

// TODO: still on the pre-rebrand subdomain; rename in Featurebase, then here.
export const FEATUREBASE_URL = 'https://subpilot.featurebase.app';

export const EULA_URL =
  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/** Section toggles: the `showTicker` / `showFaq` props from the design file. */
export const SHOW_TICKER = true;
export const SHOW_FAQ = true;
