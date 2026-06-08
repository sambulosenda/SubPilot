# SubPilot — App Store release checklist

Status legend: `[ ]` todo · `[x]` done · `[~]` partial / needs verification.

## Blockers (must clear before submit)

- [x] **CloudKit production schema deployed** (2026-06-08). Promoted
  `CD_Profile` + `CD_Subscription` record types + indexes to Production for
  `iCloud.com.sambulosenda.subradar`. Re-promote whenever the model changes.
- [x] **App Group on the distribution App ID** — provisioned automatically; the
  distribution upload (2026-06-08) signed all three App IDs
  (`com.sambulosenda.subradar`, `.SubPilotWidget`, `.ShareExtension`) with the
  App Group + CloudKit entitlements.
- [x] **First device/TestFlight build signs cleanly** — 1.0 (1) uploaded
  2026-06-08, built with **Xcode 26.2 GA (17C52)**. NOTE: must archive with the
  GA Xcode, not Xcode-beta (26.4 / 17E5179g) — App Store rejects beta-SDK builds
  (error 90534).

## Project / build (done in repo)

- [x] Widget extension (`SubPilotWidget`) wired, builds, embeds.
- [x] Share Extension (`ShareExtension`) wired as a real target, builds, embeds.
- [x] App Groups entitlement on app + both extensions.
- [x] `ITSAppUsesNonExemptEncryption = NO` set (skips the per-upload export
  compliance prompt — valid only if you add no non-exempt crypto).
- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` per release (now 1.0 / 1).

## App Store Connect

- [x] App record created (name "SubPilot"); bundle id `com.sambulosenda.subradar` registered.
- [x] Distribution certificate + provisioning (Xcode automatic) — first build uploaded.
- [ ] Screenshots (6.9" + 6.5" iPhone at minimum), description, keywords,
  promo text, support URL, category, age rating.
- [ ] **Privacy policy URL** + **App Privacy** answers. Declare:
  - CloudKit (user subscription data, stored in their iCloud — not "collected"
    by you, but disclose).
  - **logo.dev** network call (domain → brand logo) in `BrandLogoStore`
    (publishable token embedded). Confirm ToS allows shipping; declare the
    network usage.
  - No tracking / no ads / no third-party analytics (confirm).
- [ ] Sign in with Apple: N/A (no accounts).

## Pre-submit testing (real device)

- [ ] CloudKit sync across two devices signed into the same iCloud.
- [ ] AI assistant tab on an Apple-Intelligence-capable device (FoundationModels
  availability path + the unavailable fallback).
- [ ] Receipt import: PhotosPicker + Share Extension (share a PDF/image into
  SubPilot → app drains `ShareInbox` → import review).
- [ ] Widgets on device: Home (small/medium) + Lock Screen, with real data;
  countdown decrements; updates after adding/editing a subscription.
- [ ] Notifications: permission primer + a scheduled renewal reminder fires.
- [ ] Cold launch with no iCloud account (local-only fallback, no crash).

## Nice-to-have (not blocking)

- [ ] `widgetURL` deep-link so tapping the widget opens the relevant screen.
- [ ] Real brand logos in the widget (cache logo.dev images into the App Group).
- [ ] Localized strings / String Catalog review.
