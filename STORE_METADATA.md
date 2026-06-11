# SubPilot — App Store Connect listing copy

Paste-ready text for the App Store Connect listing. Character limits noted in
parentheses; everything here is within limit and avoids keyword-stuffing (which
Apple rejects).

---

## Name (30)

`SubPilot: Subscription Tracker`

> You created the record as "SubPilot". You can update the name in App Store
> Connect → App Information before submitting. The Home Screen name stays
> "SubPilot" regardless (that's `CFBundleDisplayName`).

## Subtitle (30)

Recommended: `Renewal reminders & budgeting` (29)

> Subtitle words ARE indexed. This carries three keywords — renewal, reminder,
> budget — which are therefore REMOVED from the keyword field below (no point
> paying for them twice). Earlier draft `Track renewals & spending` wasted reach
> by repeating `track` (already in the name "Tracker") and `spending`/`renewals`
> (also in the keyword field).

Alternatives (same de-dup rule applies — keep keyword field in sync):
- `Bill reminders & budgeting` (26) — swaps renewal→bill in the indexed set
- `Never miss a renewal again` (26) — benefit-first, weaker keyword coverage

## Promotional text (170 — editable any time without a new build)

`See every subscription, monthly total, and upcoming renewal at a glance — with
reminders before each charge so a free trial never turns into a surprise bill.`

## Keywords (100, comma-separated, no spaces — don't repeat words from the name OR subtitle)

`recurring,bill,trial,manage,spending,money,expense,finance,cancel,due,payment,alert,saver,cost,price`

> 100/100 chars. Changes from the first draft:
> - Dropped `track` (dupes "Tracker" in the name), `renewal`/`reminder`/`budget`
>   (now in the subtitle), so none are paid for twice.
> - Singularised `bills→bill`, `expenses→expense` (Apple indexes both forms;
>   singular saves characters).
> - Added 5 high-intent terms: `due, payment, alert, saver, cost, price`.
> - Apple stems, so `subscription` (name) covers subscriptions; don't re-add it.
>
> Caveat: these picks aren't backed by volume/difficulty data yet. Validate with
> `/keyword-research` before locking. "subscription tracker" (in the name) is
> hyper-competitive — lean on long-tail terms for early ranking wins.

## Description

```
SubPilot keeps every subscription in one place — and makes sure a forgotten
free trial never becomes a surprise charge.

Add a subscription in seconds from a catalogue of 200+ popular services, or scan
a receipt and let SubPilot read the details on your device. See your real
monthly total in your own currency, and get a reminder before every renewal and
free-trial conversion so you can cancel in time.

WHAT YOU GET

• Next-renewal at a glance — Home Screen and Lock Screen widgets show what's
  charging next and your monthly total.
• Smart reminders — a heads-up before each renewal or trial ends.
• Receipt scanning — read on-device; nothing is uploaded.
• Profiles — keep personal and work subscriptions separate.
• Multi-currency — see everything converted into one total.
• On-device AI assistant — ask about your subscriptions, powered by Apple
  Intelligence (on supported devices).
• iCloud sync — your data syncs privately across your devices.

PRIVATE BY DEFAULT

No account. No sign-up. No ads or tracking. Your subscriptions stay on your
device and sync only through your own private iCloud — we can't see them.

Take control of your recurring spending with SubPilot.

Privacy Policy: https://gist.github.com/sambulosenda/744ff503ade4a19c0a4ac298160248f9
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

> **Required by 3.1.2(c)** (App Review rejection, Jun 10 2026, submission
> 03e22645): apps with auto-renewable subscriptions using Apple's standard
> EULA must link it in the App Description. Keep these two lines in every
> future description edit.

## What's New (4000) — for 1.0

```
Welcome to SubPilot 1.0.

• Track all your subscriptions in one place
• Home Screen & Lock Screen widgets for your next renewal and monthly total
• Reminders before renewals and free-trial conversions
• On-device receipt scanning and an Apple Intelligence assistant
• Private iCloud sync across your devices

Thanks for trying SubPilot — feedback is welcome at sambulosendas@gmail.com.
```

## Other listing fields

- **Primary category:** Finance
- **Secondary category:** Productivity (or Utilities)
- **Age rating:** 4+ (no objectionable content)
- **Support URL:** `https://sambulosenda.com/` — has a visible contact email
  (`sambulosendas@gmail.com`) + social links, which satisfies guideline 1.5.
- **Marketing URL:** optional.
- **Privacy Policy URL:** _required_ — host `PRIVACY_POLICY.md` and link it
  (see below).

---

## App Privacy questionnaire (the "nutrition label")

Answer: **Data Not Collected.**

Rationale (so you can answer each prompt confidently):
- There is **no developer-operated server** and **no account**. Your data never
  reaches us.
- **iCloud/CloudKit** data lives in the user's *own private* database. Apple's
  guidance is that private CloudKit data the developer cannot access is **not
  "collected"** by you.
- **logo.dev** receives only a brand **domain**; **frankfurter.app** receives
  only a **currency code**. Neither is personal data or a user identifier, so
  neither counts as "collected" or "tracking."
- **No analytics, no ads, no tracking SDKs** (verified — zero third-party
  dependencies).

So when App Store Connect asks "Do you or your third-party partners collect data
from this app?" → **No**.

(If you'd rather be maximally conservative, you *could* disclose CloudKit data
as collected-but-not-linked and not-for-tracking — but "Data Not Collected" is
accurate and defensible here.)

---

## Hosting the privacy policy

You need an `https://` URL for the Privacy Policy field. Quickest paths:
- **GitHub Pages:** push `PRIVACY_POLICY.md` to a public repo with Pages enabled.
- **GitHub Gist:** paste the content into a public gist and use its URL.
- **Notion / your own site:** paste and publish.

Use that URL in App Store Connect → App Privacy → Privacy Policy URL, and (good
practice) also link it from the in-app Settings.
