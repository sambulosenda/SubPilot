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
>
> **Keep "Tracker," not "Manager"** (Astro top-10 benchmark, Jun 2026): the
> "subscription manager" field is walled off — its weakest ranking app has ~116
> ratings and the rest run 1,600–360,000 (Bobby, Kango, NerdWallet, Finelo).
> The "subscription tracker" field has 0- and 42-rating apps ranking, so it's
> winnable at 0 ratings. Revisit "Manager" after ~100+ ratings.

## Subtitle (30)

Recommended: `Manage renewals & reminders` (27)

> Subtitle words ARE indexed (2nd-highest weight). This puts `manage` in the
> subtitle to target **manage subscriptions** (pop 14 / diff 42) — a *winnable*
> term per the Astro top-10 benchmark (its field has 0- and 9-rating apps
> ranking). `manage` + `Subscription` (name) forms the phrase; `manage` also
> stems to manager/managing. Carries manage, renewal, reminder — all REMOVED
> from the keyword field below (no paying twice).

Alternatives:
- `Renewal reminders & budgeting` (29) — prior version; pure conversion, no
  winnable keyword (renewal = pop 6, budget terms dead). Safe but lower reach.
- `Cancel & renewal reminders` (26) — swaps in `cancel` (pop 33, higher) but
  diff 47, it's Finelo's turf, and risks implying auto-cancel. Honest only as
  "reminders to cancel."

## Promotional text (170 — editable any time without a new build)

`See every subscription, monthly total, and upcoming renewal at a glance — with
reminders before each charge so a free trial never turns into a surprise bill.`

## Keywords (100, comma-separated, no spaces — don't repeat words from the name OR subtitle)

`cancel,recurrent,recurring,receipt,scan,trial,forgotten,private,organizer,widget,bill,spending,alert`

> 100/100 chars. Now backed by Astro popularity/difficulty + a top-10
> winnability benchmark (Jun 2026). Changes from the prior draft:
> - **Removed** `manage` (now in the subtitle) and `money,finance,cost,price,
>   saver,due,payment` — generic guesses with no volume signal; `finance` is
>   also your category (Apple already knows it = wasted).
> - **Added** `recurrent` (pop 15 / diff 15 — easiest win in the set),
>   `receipt,scan` (pop-56 "receipt scanner" + a real feature you ship),
>   `forgotten` (high intent), `private` (your #1 differentiator), `organizer,
>   widget` (features).
> - `cancel` + `Subscription` (name) → "subscription cancel" / "cancel
>   subscription" (the pop-33 cluster).
> - De-dup: nothing repeats the name (subscription, tracker) or subtitle
>   (manage, renewal, reminder). Apple stems singular/plural and manage→manager.
>
> Benchmark verdict: target the **tracker** family (name) + **manage** (subtitle)
> + `recurrent` — their top-10s contain weak/new apps a 0-rating app can pass.
> `subscription manager` (noun) and `receipt scanner` are walled off by
> Bobby/Kango/NerdWallet for now — `receipt`/`scan` are indexed here cheaply so
> you're positioned when authority grows. Re-check the Astro **Ranking** column
> ~3–4 weeks after shipping.

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
