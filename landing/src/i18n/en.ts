// English copy, the default for every component. The German counterpart in
// de.ts must keep the same shape. HTML-bearing strings (used via set:html)
// end in `Html` and may contain <em>, <b> and <br class="hold" /> only.

export default {
  meta: {
    title: 'SubHelm: Subscription Tracker & Renewal Reminders for iPhone',
    description:
      'Track every subscription in one place. See your real monthly total and get reminders before each charge. No account, no ads, no tracking. Free on iPhone.',
  },
  header: {
    homeHref: '/',
    links: [
      { label: 'How it works', href: '/#how' },
      { label: 'Features', href: '/#features' },
      { label: 'Privacy', href: '/#privacy' },
      { label: 'Guides', href: '/guides/' },
    ],
    cta: 'Get the app',
  },
  badge: {
    small: 'Download on the',
    strong: 'App Store',
    aria: 'Download on the App Store',
  },
  hero: {
    kicker: 'Subscription tracker for iPhone',
    titleHtml: `Know exactly what's<br class="hold" /> charging you <em>next</em>.`,
    sub: 'Every subscription in one place, your real monthly total, and a reminder before each charge, so a free trial never quietly becomes a bill.',
    noteHtml: 'Free · <b>Pro</b> available in-app',
    phoneAlt:
      'SubHelm home screen showing a total monthly spend of $119.13 and upcoming renewals',
    pill1: { title: 'Netflix renews in 2 days', sub: 'US$17.99 / mo' },
    pill2: { title: 'Trial ends Friday', sub: 'Reminder set' },
  },
  ticker: [
    'No account',
    'No ads',
    'No tracking',
    'On-device AI',
    'Private iCloud sync',
    'Multi-currency',
    'Widgets',
  ],
  how: {
    titleHtml: 'Three taps in, and you never guess <em>again</em>.',
    lead: 'Setting up takes about a minute. After that, SubHelm does the remembering.',
    steps: [
      {
        title: 'Add',
        body: 'Pick from a catalogue of 200+ services, or point the camera at a receipt and let it read the details.',
      },
      {
        title: 'See',
        body: 'One honest monthly total, every currency converted, personal and work kept apart.',
      },
      {
        title: 'Know',
        body: 'A reminder arrives before each renewal, and before a trial turns into a paid plan.',
      },
    ],
  },
  showcase: {
    rows: [
      {
        kicker: 'Calendar',
        titleHtml: 'The month, before it happens.',
        body: "Every upcoming charge and trial ending laid out day by day. You see the expensive week coming while there's still time to cancel something.",
        alt: 'Calendar of upcoming subscription charges in SubHelm',
      },
      {
        kicker: 'Assistant',
        titleHtml: 'Ask it anything. It answers <em>on your phone</em>.',
        body: '"Where could I cut back?" "What renews in the next 7 days?" Powered by Apple Intelligence, running on-device, so the questions and the answers never leave it.',
        alt: "SubHelm's on-device assistant answering a question about subscription spending",
      },
      {
        kicker: 'Receipt scanning',
        titleHtml: 'Point the camera. Done.',
        body: "Found a charge you don't recognise on a receipt? Scan it and the name, price and date are read straight into SubHelm. Nothing is uploaded anywhere.",
        alt: 'Scanning a receipt to add a subscription in SubHelm',
      },
    ],
    chips: ['How much do I spend per year?', 'Where could I cut back?'],
  },
  features: {
    title: 'Small things that make it stick.',
    cells: [
      {
        title: 'Widgets',
        body: 'Your next renewal and monthly total on the Home and Lock Screen.',
      },
      {
        title: 'Smart reminders',
        body: 'A heads-up before each renewal, and before a free trial converts.',
      },
      {
        title: '200+ services',
        body: 'Netflix, Spotify, ChatGPT and more, added in a few seconds.',
      },
      {
        title: 'Profiles',
        body: 'Personal and work kept separate, each with its own total.',
      },
      {
        title: 'Multi-currency',
        body: 'Subscriptions in any currency, converted into one real total.',
      },
      {
        title: 'iCloud sync',
        body: 'Across your devices, through your own private iCloud.',
      },
    ],
  },
  privacy: {
    kicker: 'Privacy',
    titleHtml: "There's no server to send your data <em>to</em>.",
    body: "Your subscriptions live on your device and sync only through your own iCloud. There's nothing to sign up for, nothing to log in to, and nothing we could look at if we wanted to.",
    facts: [
      { label: 'Accounts required', value: 'None' },
      { label: 'Third-party trackers', value: 'Zero' },
      { label: 'Ads', value: 'Never' },
      { label: 'Bank connection', value: 'Not asked' },
    ],
  },
  faq: {
    title: 'Questions, answered.',
    items: [
      {
        q: 'Do I need to connect my bank?',
        a: 'No. SubHelm never asks for bank credentials. You add subscriptions from a built-in catalogue, by hand, or by scanning a receipt.',
      },
      {
        q: 'Is there an account to create?',
        a: "There isn't. Open the app and start adding. Your data stays on your device and syncs through your own iCloud if you have more than one.",
      },
      {
        q: 'What does the assistant send to a server?',
        a: 'Nothing. It runs on-device through Apple Intelligence, so both your question and its answer stay on your iPhone.',
      },
      {
        q: 'Can it handle subscriptions in other currencies?',
        a: "Yes. Add them in whatever currency you're billed in and SubHelm converts everything into one monthly total.",
      },
      {
        q: 'Will it remind me before a free trial ends?',
        a: 'Yes. Mark a subscription as a trial and SubHelm sends a reminder before it converts into a paid plan, and before every renewal after that.',
      },
      {
        q: 'Can SubHelm cancel subscriptions for me?',
        a: "No, and nobody else can either without your account credentials. SubHelm shows you what to cancel and reminds you before the charge, while there's still time to do it; you cancel with the provider, which usually takes a minute.",
      },
      {
        q: "What's in SubHelm Pro?",
        a: 'The app is free to download and use. Pro is an optional in-app upgrade; you can see exactly what it includes inside the app before buying anything.',
      },
    ],
  },
  finalCta: {
    titleHtml: 'Take control of your<br class="hold" /> recurring spending.',
    note: 'Free on the App Store. No account, no ads, no tracking.',
    iconAlt: 'SubHelm app icon',
  },
  footer: {
    guides: 'Guides',
    guidesHref: '/guides/',
    cancelGuides: 'Cancel guides',
    cancelHref: '/cancel/',
    featureRequests: 'Feature requests',
    privacyPolicy: 'Privacy policy',
    terms: 'Terms of use',
    support: 'Support',
  },
  guide: {
    crumbHome: 'Home',
    published: 'Published ',
    updated: 'Updated ',
    dateLocale: 'en-GB',
    faqTitle: 'Common questions',
    relatedTitle: 'Related guides',
    ctaTitle: 'Let the app do the remembering',
    ctaBody:
      'SubHelm keeps every subscription, trial and renewal in one place on your iPhone. No account, no bank connection, free to use.',
  },
};
