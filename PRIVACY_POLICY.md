# SubHelm — Privacy Policy

_Last updated: 2 July 2026_

SubHelm is built privacy-first. There is no account, no sign-up, and no
advertising or cross-app tracking. This policy explains exactly what happens
to your data.

## The short version

- Your subscriptions are stored **on your device**.
- If you're signed into iCloud, they sync through **your own private iCloud
  account** (Apple CloudKit). We, the developers, **cannot see them**.
- We do **not** collect, sell, or share your personal data. Your subscription
  names, amounts, and notes never leave your device for our benefit.
- We use **anonymous, aggregate product analytics** (TelemetryDeck) to
  understand which features are used — never your content, and you can turn
  it off in Settings. There are no advertising or tracking SDKs.

## What we collect

Your subscription data, spending totals, and profiles never reach us — SubHelm
has no developer-operated servers and no account system.

To improve the app we collect **anonymous usage analytics** via
[TelemetryDeck](https://telemetrydeck.com), a privacy-focused analytics
service based in Germany (GDPR-compliant). What this includes:

- Which features are used (for example "a subscription was added via scan",
  "the paywall was shown") and simple counts, plus general device information
  such as app version, iOS version, and device type.
- A **salted, hashed identifier** derived from a per-app Apple vendor ID, used
  only so repeat launches aren't counted as new users. TelemetryDeck cannot
  reverse it or link it to you, and it cannot be used to track you across apps.

What it **never** includes: subscription names, amounts, notes, currencies,
or any content you enter. Analytics can be disabled at any time with
**Settings → Share anonymous usage data**; the app works identically with it
off. TelemetryDeck's own policy is at
[telemetrydeck.com/privacy](https://telemetrydeck.com/privacy/).

## Where your data lives

- **On your device**, in the app's local database.
- **In your private iCloud database** (Apple CloudKit), *only if* you are signed
  into iCloud. This is the standard mechanism Apple provides to sync your data
  across your own devices and back it up. Access is controlled by your Apple
  account; the developers have no access to it. Apple's handling of this data is
  governed by [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).

## Network requests

SubHelm makes a small number of network requests. **None of them include
your subscription content or any personal data that identifies you.**

1. **Brand logos** — to show a logo next to a subscription, the app sends the
   brand's public website **domain** (for example, `netflix.com`) to
   [logo.dev](https://logo.dev) and receives a logo image. No personal
   information is sent.
2. **Currency exchange rates** — to convert amounts into your preferred
   currency, the app requests reference rates from
   [frankfurter.app](https://www.frankfurter.app), sending only a **currency
   code** (for example, `GBP`). No personal information is sent.
3. **Anonymous analytics** — usage events are sent to
   [TelemetryDeck](https://telemetrydeck.com) as described above, unless you
   turn analytics off in Settings.
4. **iCloud sync** — handled by Apple CloudKit as described above.

If you are offline, the app falls back gracefully (generic icons, last-known
rates) and keeps working.

## Receipts and the AI assistant

- **Receipt scanning** is performed **entirely on your device**. Receipt images
  are read locally to pre-fill subscription details and are never uploaded.
- The **AI assistant** runs **on-device** using Apple Intelligence on supported
  hardware. Your subscription information is not sent to any external AI service.

## Notifications

Renewal and free-trial reminders are scheduled **locally on your device**. They
are not sent through any external service.

## Your choices

- **Delete data:** remove any subscription or profile in the app at any time.
- **Stop iCloud sync:** sign out of iCloud, or disable iCloud for SubHelm in
  the iOS Settings app.

## Children

SubHelm is not directed at children and does not knowingly collect any data
from anyone. It is rated 4+.

## Changes to this policy

If this policy changes, the "Last updated" date above will change. Material
changes will be reflected in an app update.

## Contact

Questions about privacy? Email **sambulosendas@gmail.com**.
