// German copy, du-form, terminology matched to the app's own localization
// (Abos, Verlängerung, Gratis-Testphase). Same shape as en.ts.
import type en from './en';

const de: typeof en = {
  meta: {
    title: 'SubHelm: Abo-Tracker & Erinnerungen vor jeder Abbuchung',
    description:
      'Alle Abos an einem Ort. Echte Monatskosten und eine Erinnerung vor jeder Abbuchung. Kein Konto, keine Werbung, kein Tracking. Gratis fürs iPhone.',
  },
  header: {
    homeHref: '/de/',
    links: [
      { label: "So funktioniert's", href: '/de/#how' },
      { label: 'Funktionen', href: '/de/#features' },
      { label: 'Privatsphäre', href: '/de/#privacy' },
      { label: 'Guides', href: '/de/guides/' },
    ],
    cta: 'App laden',
  },
  badge: {
    small: 'Laden im',
    strong: 'App Store',
    aria: 'Im App Store laden',
  },
  hero: {
    kicker: 'Abo-Tracker für dein iPhone',
    // No hold-break here: German runs longer than English, and forcing the
    // two-line composition leaves an orphaned word. Three balanced lines win.
    titleHtml: `Du siehst jede Abbuchung, <em>bevor</em> sie kommt.`,
    sub: 'Alle Abos an einem Ort, deine echten Monatskosten und eine Erinnerung vor jeder Abbuchung, damit aus einer Gratis-Testphase nie stillschweigend eine Rechnung wird.',
    noteHtml: 'Gratis · <b>Pro</b> optional in der App',
    phoneAlt:
      'SubHelm-Startbildschirm mit monatlichen Gesamtkosten von 119,13 $ und anstehenden Verlängerungen',
    pill1: { title: 'Netflix verlängert sich in 2 Tagen', sub: '17,99 $ / Monat' },
    pill2: { title: 'Testphase endet Freitag', sub: 'Erinnerung aktiv' },
  },
  ticker: [
    'Kein Konto',
    'Keine Werbung',
    'Kein Tracking',
    'KI auf dem Gerät',
    'Private iCloud-Synchronisierung',
    'Alle Währungen',
    'Widgets',
  ],
  how: {
    titleHtml: 'Drei Taps, und du rätst nie <em>wieder</em>.',
    lead: 'Die Einrichtung dauert etwa eine Minute. Danach merkt sich SubHelm alles für dich.',
    steps: [
      {
        title: 'Hinzufügen',
        body: 'Wähle aus einem Katalog mit über 200 Diensten, oder richte die Kamera auf einen Beleg und lass die Details auslesen.',
      },
      {
        title: 'Sehen',
        body: 'Ehrliche Monatskosten: jede Währung umgerechnet, Privates und Berufliches getrennt.',
      },
      {
        title: 'Wissen',
        body: 'Eine Erinnerung kommt vor jeder Verlängerung, und bevor aus einer Testphase ein bezahltes Abo wird.',
      },
    ],
  },
  showcase: {
    rows: [
      {
        kicker: 'Kalender',
        titleHtml: 'Der Monat, bevor er passiert.',
        body: 'Jede anstehende Abbuchung und jedes Testphasen-Ende, Tag für Tag. Du siehst die teure Woche kommen, solange noch Zeit zum Kündigen ist.',
        alt: 'Kalender mit anstehenden Abo-Abbuchungen in SubHelm',
      },
      {
        kicker: 'Assistent',
        titleHtml: 'Frag ihn alles. Er antwortet <em>auf deinem iPhone</em>.',
        body: '„Wo könnte ich sparen?" „Was verlängert sich in den nächsten 7 Tagen?" Mit Apple Intelligence, direkt auf dem Gerät: Fragen und Antworten verlassen es nie.',
        alt: 'SubHelms Assistent beantwortet auf dem Gerät eine Frage zu Abo-Ausgaben',
      },
      {
        kicker: 'Beleg scannen',
        titleHtml: 'Kamera drauf. Fertig.',
        body: 'Eine Abbuchung auf einem Beleg, die du nicht zuordnen kannst? Scanne ihn, und Name, Preis und Datum landen direkt in SubHelm. Nichts wird hochgeladen.',
        alt: 'Beleg scannen, um ein Abo in SubHelm hinzuzufügen',
      },
    ],
    chips: ['Wie viel gebe ich pro Jahr aus?', 'Wo könnte ich sparen?'],
  },
  features: {
    title: 'Kleinigkeiten, die hängen bleiben.',
    cells: [
      {
        title: 'Widgets',
        body: 'Nächste Verlängerung und Monatskosten auf Home- und Sperrbildschirm.',
      },
      {
        title: 'Smarte Erinnerungen',
        body: 'Ein Hinweis vor jeder Verlängerung, und bevor eine Gratis-Testphase kostenpflichtig wird.',
      },
      {
        title: 'Über 200 Dienste',
        body: 'Netflix, Spotify, ChatGPT und mehr, in Sekunden hinzugefügt.',
      },
      {
        title: 'Profile',
        body: 'Privat und beruflich getrennt, jeweils mit eigener Summe.',
      },
      {
        title: 'Alle Währungen',
        body: 'Abos in jeder Währung, umgerechnet in eine echte Gesamtsumme.',
      },
      {
        title: 'iCloud-Sync',
        body: 'Auf all deinen Geräten, über deine eigene private iCloud.',
      },
    ],
  },
  privacy: {
    kicker: 'Privatsphäre',
    titleHtml: 'Es gibt keinen Server, an den deine Daten gehen <em>könnten</em>.',
    body: 'Deine Abos bleiben auf deinem Gerät und synchronisieren nur über deine eigene iCloud. Nichts zum Registrieren, nichts zum Einloggen, und nichts, das wir einsehen könnten, selbst wenn wir wollten.',
    facts: [
      { label: 'Konto erforderlich', value: 'Keins' },
      { label: 'Dritt-Tracker', value: 'Null' },
      { label: 'Werbung', value: 'Nie' },
      { label: 'Bankverbindung', value: 'Nie gefragt' },
    ],
  },
  faq: {
    title: 'Fragen, beantwortet.',
    items: [
      {
        q: 'Muss ich mein Bankkonto verbinden?',
        a: 'Nein. SubHelm fragt nie nach Bankdaten. Du fügst Abos aus dem Katalog hinzu, von Hand oder per Beleg-Scan.',
      },
      {
        q: 'Muss ich ein Konto erstellen?',
        a: 'Nein. App öffnen und loslegen. Deine Daten bleiben auf dem Gerät und synchronisieren über deine eigene iCloud, wenn du mehrere Geräte hast.',
      },
      {
        q: 'Was schickt der Assistent an einen Server?',
        a: 'Nichts. Er läuft mit Apple Intelligence direkt auf dem Gerät; Frage und Antwort bleiben auf deinem iPhone.',
      },
      {
        q: 'Kann SubHelm Abos in anderen Währungen verwalten?',
        a: 'Ja. Füge sie in der Währung hinzu, in der du zahlst; SubHelm rechnet alles in eine Monatssumme um.',
      },
      {
        q: 'Erinnert mich SubHelm vor dem Ende einer Gratis-Testphase?',
        a: 'Ja. Markiere ein Abo als Testphase, und SubHelm erinnert dich, bevor es kostenpflichtig wird, und vor jeder Verlängerung danach.',
      },
      {
        q: 'Kann SubHelm Abos für mich kündigen?',
        a: 'Nein, und ohne deine Zugangsdaten kann das auch niemand sonst. SubHelm zeigt dir, was du kündigen solltest, und erinnert dich rechtzeitig vor der Abbuchung; gekündigt wird beim Anbieter, meist in einer Minute.',
      },
      {
        q: 'Was steckt in SubHelm Pro?',
        a: 'Die App ist gratis. Pro ist ein optionales Upgrade in der App; was es enthält, siehst du dort, bevor du irgendetwas kaufst.',
      },
    ],
  },
  finalCta: {
    titleHtml: 'Übernimm die Kontrolle über<br class="hold" /> deine Abo-Ausgaben.',
    note: 'Gratis im App Store. Kein Konto, keine Werbung, kein Tracking.',
    iconAlt: 'SubHelm App-Icon',
  },
  footer: {
    guides: 'Guides',
    guidesHref: '/de/guides/',
    cancelGuides: 'Kündigungs-Guides',
    featureRequests: 'Feature-Wünsche',
    privacyPolicy: 'Datenschutz',
    terms: 'Nutzungsbedingungen',
    support: 'Support',
  },
  guide: {
    crumbHome: 'Start',
    published: 'Veröffentlicht am ',
    updated: 'Aktualisiert am ',
    dateLocale: 'de-DE',
    ctaTitle: 'Lass die App sich erinnern',
    ctaBody:
      'SubHelm behält jedes Abo, jede Testphase und jede Verlängerung auf deinem iPhone im Blick. Kein Konto, keine Bankverbindung, gratis nutzbar.',
  },
};

export default de;
