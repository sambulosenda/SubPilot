# Recurra — App Store release checklist

Status legend: `[ ]` todo · `[x]` done · `[~]` partial / needs verification.

## Blockers (must clear before submit)

- [x] **CloudKit production schema deployed** (2026-06-08). Promoted
  `CD_Profile` + `CD_Subscription` record types + indexes to Production for
  `iCloud.com.sambulosenda.subradar`. Re-promote whenever the model changes.
- [x] **App Group on the distribution App ID** — provisioned automatically; the
  distribution upload (2026-06-08) signed all three App IDs
  (`com.sambulosenda.subradar`, `.RecurraWidget`, `.ShareExtension`) with the
  App Group + CloudKit entitlements.
- [x] **First device/TestFlight build signs cleanly** — 1.0 (1) uploaded
  2026-06-08, built with **Xcode 26.2 GA (17C52)**. NOTE: must archive with the
  GA Xcode, not Xcode-beta (26.4 / 17E5179g) — App Store rejects beta-SDK builds
  (error 90534).

## Project / build (done in repo)

- [x] Widget extension (`RecurraWidget`) wired, builds, embeds.
- [x] Share Extension (`ShareExtension`) wired as a real target, builds, embeds.
- [x] App Groups entitlement on app + both extensions.
- [x] `ITSAppUsesNonExemptEncryption = NO` set (skips the per-upload export
  compliance prompt — valid only if you add no non-exempt crypto).
- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` per release (now 1.0 / 1).

## App Store Connect

- [x] App record created (name "Recurra"); bundle id `com.sambulosenda.subradar` registered.
- [x] Distribution certificate + provisioning (Xcode automatic) — first build uploaded.
- [x] **In-App Purchase products** created in ASC + IAP capability enabled;
  Pro products attached to the 1.0 version for review.
- [x] **Screenshots** captured (6.9" + 6.5") and uploaded.
- [x] **Support URL:** `https://sambulosenda.com/` (visible contact email +
  socials — satisfies guideline 1.5).
- [~] Listing copy **drafted** in `STORE_METADATA.md` (name, subtitle, keywords,
  description, promo, what's-new, category=Finance, age=4+). Still needed:
  pasting it into ASC.
- [ ] **3.1.2(c) rejection fix (Jun 10 2026):** description must end with the
  Privacy Policy + standard-EULA links (now in `STORE_METADATA.md`). Paste the
  updated description into ASC, add a note in App Review Information → Notes
  ("Standard Apple EULA linked in App Description; in-app paywall shows title,
  length, price, privacy + terms links"), attach a paywall screen recording to
  the App Review reply, then resubmit.
- [~] **Privacy policy drafted** in `PRIVACY_POLICY.md`; **App Privacy = "Data
  Not Collected"** (verified: no analytics/ads/tracking, no external deps; only
  outbound calls are CloudKit, img.logo.dev [brand domain], api.frankfurter.app
  [currency code] — none personal). Still needed: **host the policy** at an
  https URL and paste it + the answers into App Store Connect.
- [ ] Sign in with Apple: N/A (no accounts).

## Pre-submit testing (real device)

- [x] CloudKit sync across two devices signed into the same iCloud.
- [x] AI assistant tab on an Apple-Intelligence-capable device (FoundationModels
  availability path + the unavailable fallback).
- [x] Receipt import: PhotosPicker + Share Extension (share a PDF/image into
  Recurra → app drains `ShareInbox` → import review).
- [x] Widgets on device: Home (small/medium) + Lock Screen, with real data;
  countdown decrements; updates after adding/editing a subscription.
- [x] Notifications: permission primer + a scheduled renewal reminder fires.
- [x] Cold launch with no iCloud account (local-only fallback, no crash).

## Nice-to-have (not blocking)

- [ ] `widgetURL` deep-link so tapping the widget opens the relevant screen.
- [ ] Real brand logos in the widget (cache logo.dev images into the App Group).
- [ ] Localized strings / String Catalog review.
