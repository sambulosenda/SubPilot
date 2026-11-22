# Screenshots v6 — headlines + asset plan

App: **SubHelm: Subscription Tracker** (id6777939621), iPhone-only
(`TARGETED_DEVICE_FAMILY = 1`). Dark set, 1290×2796.

Supersedes `screenshots/v5/` (5 slots, light, Jul 22 2026).

---

## 0. Blocker — read first

A **Product Page Optimization test is still live in ASC** (started Jul 8 2026).
Last read: baseline 29.68%, Treatment A 32.45% @ **8.5% confidence**, B 20.66% @ 3.5%.
Apple calls a winner at 90% — nothing there is decidable.

Swapping the default screenshots mid-test muddies it. Before shipping v6:
**Distribution → Product Page Optimization → Stop test** (not Analytics → Product
Pages, which is read-only). Stopping is one-way; a stopped test can't be resumed.

Also still open: the stray empty **"1.0.9 Prepare for Submission"** draft above 1.8
(1.0.9 sorts below 1.8, so it can't ship). Delete it before uploading assets.

---

## 1. What's wrong with the current draft

The 6 frames in the builder carry placeholder streaming-app copy ("Stream Thousands
of Movies & Shows", "Watch Anytime, Anywhere", …). Beyond the copy:

| # | Frame | Problem |
|---|---|---|
| 3 | Adobe detail | Same brand + same form aesthetic as 4 and 5 — 3 of 6 slots look identical at thumbnail size |
| 4 | New Subscription form | A data-entry screen. Forms signal *work*, not payoff — weakest possible slot-4 |
| 5 | Cancel sheet | Good screen, keep |
| 5/6 | — | **Duplicate headline** ("Experience 4K and HD Streaming" twice) |
| — | missing | The renewal-warning banner (v5 slot 2) — the emotional payoff |
| — | missing | The no-bank-login wedge (v5 slot 3) — the one thing Rocket Money can't say |

Slots 1–3 are what render in **search results**; 80% of the decision happens there.
Right now slot 3 is an Adobe form.

---

## 2. Recommended set (v6)

Reuses 4 existing frames, needs 2 new captures.

| # | Headline | Subhead | Screen | Source |
|---|---|---|---|---|
| 1 | Stop paying for subs you **forgot** | Every subscription, one running total | Home dashboard | ✅ have (frame 1) |
| 2 | A warning before **every** charge | Cancel free trials before they bill you | Lock Screen banner | 🔴 new capture |
| 3 | No bank login. **Ever.** | Stays on your iPhone and iCloud | Home, inverted/teal | 🔴 new capture |
| 4 | See the whole **month** ahead | Renewals and totals on a calendar | Calendar | ✅ have (frame 2) |
| 5 | Cancel without the **runaround** | Step-by-step, for every service | Cancel sheet | ✅ have (frame 5) |
| 6 | Add a sub in **seconds** | 200+ services, or scan a receipt | Catalogue | ✅ have (frame 6) |

Drop frames 3 (Adobe detail) and 4 (New Subscription form).

Ordering rationale: pain hook → emotional payoff → differentiator above the fold;
calendar / cancel / add are for the scroller who's already interested.

**Optional slot 7** — the Assistant tab. Nothing in v5 or the current draft shows it,
and "ask about your spending" is a real differentiator. Seed with `-DemoAssistant`.
Headline: *Ask where the money goes*.

---

## 3. Drop-in alternative (keep all 6 existing frames)

If you don't want to re-capture — paste these over the placeholders as-is:

| # | Frame | Headline | Subhead |
|---|---|---|---|
| 1 | Home | Stop paying for subs you **forgot** | Every subscription, one running total |
| 2 | Calendar | See the whole **month** ahead | Renewals and totals on a calendar |
| 3 | Adobe detail | Know the cost **before** it hits | Every renewal date, every amount |
| 4 | New Subscription | Add a sub in **seconds** | Or scan a receipt and let it fill |
| 5 | Cancel sheet | Cancel without the **runaround** | Step-by-step, for every service |
| 6 | Catalogue | 200+ services, **ready to add** | Streaming, software, music, more |

Weaker than §2 — no banner, no privacy wedge, and slots 3–5 still read samey.

---

## 4. Copy rules applied

- 4–6 words, max 2 lines. One accent word per headline (teal), matching `render.py`'s
  `*star*` markup.
- Benefit, not feature. "Cancel without the runaround", not "Cancellation Guides".
- Subhead does the specifics so the headline can stay short.
- Apple does **not** index screenshot text — these are conversion copy, not keywords.
  Keyword work stays in title/subtitle/keyword field (see `fastlane/metadata/`).

---

## 5. Capture recipe

iPhone 17 Pro sim (1206×2622), **dark**, USD.

```bash
U=176BC4E3-CD5B-41B5-BBEB-24D66A82490E
B=com.sambulosenda.subradar
xcrun simctl ui $U appearance dark
xcrun simctl launch $U $B -DemoSeed
```

Extra args: `-StartTab calendar|assistant|settings`, `-StartRoute <name>` (push a
detail screen), `-DemoAssistant`, `-DemoNotify`.

Gotchas (all previously hit):

- `simctl io screenshot` needs **Simulator.app running with a real device window**.
  "Screen has no framebuffer surface" → `killall Simulator; open -a Simulator`.
  The MCP panel's own screenshot works but returns a downscaled image, not a file.
- SampleData pins renewals to days **4/9/11/15/19/23/27** — the current month looks
  empty late in the month. Page forward for a full grid; pick a day that has a renewal
  or the detail area reads "Nothing on <date>".
- **Notification banner:** `simctl uninstall` + `install` (resets auth) → launch with
  `-DemoSeed` → tap **Allow** → `simctl push booted $B push.json` → LOCK → screenshot.
  iOS 26 anchors banners to the **bottom**, so scale the device up in the composite or
  it's illegible at thumbnail size.
- **Never capture on an unsigned build.** `CODE_SIGNING_ALLOWED=NO` strips the iCloud
  entitlement → Settings tab crashes (SIGTRAP in `CKContainer(identifier:)`).

---

## 5b. Capture status — `sim-shots/v6/` (Jul 27 2026)

Captured today, dark, **USD** (`-preferredCurrencyCode USD -AppleLocale en_US`).
Home total reads **$147.10 / $1,765.18 yr**, calendar **Aug 2026 · 8 renewals ·
$137.94** — consistent across the set.

| File | Slot | State |
|---|---|---|
| `01-home.png` | 1 + 3 | ✅ clean |
| `02-calendar.png` | 4 | ✅ clean — Aug 4 selected, "in 8 days", Netflix $17.99 |
| `03-cancel.png` | 5 | ✅ clean — Adobe "How it works" 3 steps |
| `04-catalogue.png` | 6 | ⚠️ usable — **BINGE row has no logo** (missing catalogue asset) |
| `05-lock.png` | 2 | ⚠️ needs post — see below |

`-StartRoute Adobe` works and lands straight on the detail screen. Note the raws are
1206×2622 (device points ×3 is not needed; `render.py` scales them into the frame).

### `05-lock.png` — two fixes needed

1. **Two stray notifications** sit under ours — "Your morning with God" (Berea) and
   "Today's spelling bee" (Spelling Bee), both your own apps on this sim. Lock-screen
   swipe-to-clear doesn't work on the collapsed stack. Either crop below our banner in
   the composite (it's topmost, so a crop is clean), or `simctl uninstall`
   `com.sambulosendas1.ScriptureAI` and `com.sambulosendas1.Spelling-Bee` and re-push.
2. **Date reads "Sat 1 Jan"** — the known sim Lock Screen date. Run `fixdate.py`.

Banner copy pushed via `simctl push` was **"Netflix renews soon / $17.99 will be charged
on Aug 4."** — deliberately matched to the calendar slot.

> Separately: the app's own `-DemoNotify` helper hardcodes **"$17.99 will be charged on
> 8 Jul."** (`NotificationManager.swift:261`) — a past date, so the helper can't be used
> for captures as-is. `simctl push` sidesteps it, but worth fixing or deleting.

---

## 6. Render + deliver

Two paths, pick one:

**A. Script** (`screenshots/v5/render.py` → fork to `screenshots/v6/render.py`).
Pillow, needs a venv (Pillow isn't in system python). Reproducible and scriptable for
localisation — swap a headline dict per locale and re-run. `fixdate.py` patches the
Lock Screen date.

**B. The web builder** already open. Faster for one locale, manual for six.

Recommend **A** given §7.

Output: `1290×2796` only (6.9" iPhone) — that's the sole required size for an
iPhone-only app. `1284×2778` optional legacy.

---

## 7. Localisation

`fastlane/metadata/` has 6 locales: en-US, en-GB, de-DE, es-ES, fr-FR, it.
Screenshots are English-only today. German is the priority market per the ASO keyword
work — localised screenshots there are the highest-value follow-on.

### German (de-DE) — drafted

App's German strings are **du-form throughout** (55 du / 0 Sie, checked in
`Localizable.xcstrings`). Headlines below match that register.

| # | Headline | Subhead |
|---|---|---|
| 1 | Schluss mit **vergessenen** Abos | Alle Abos, eine laufende Summe |
| 2 | Warnung vor **jeder** Abbuchung | Testphasen kündigen, bevor sie kosten |
| 3 | Kein Bank-Login. **Nie.** | Bleibt auf deinem iPhone und in iCloud |
| 4 | Der ganze **Monat** im Blick | Verlängerungen und Summen im Kalender |
| 5 | Kündigen ohne **Irrwege** | Schritt für Schritt, für jeden Dienst |
| 6 | Abo in **Sekunden** hinzufügen | 200+ Dienste oder Beleg scannen |

German runs ~15–20% longer than English — slot 6 and slot 4 are the tight ones. Either
drop `head_size` from 116 to ~104 for de, or let `draw_headline` take 3 lines.

Re-capture the raws with `-AppleLocale de_DE -AppleLanguages "(de-DE)"` and
`-preferredCurrencyCode EUR` so the in-device text and currency match.

fr / es / it not drafted — say the word.

---

## 8. Order of operations

1. Stop the PPO test in ASC; delete the stray 1.0.9 draft.
2. Capture the 2 new frames (banner, privacy) on a **signed** build.
3. Render all 6 at 1290×2796.
4. Upload to the 1.8(2) version alongside the pending resubmission.
5. Once live and stable ~2 weeks, start a *new* PPO test — v6 vs v5 — and let it reach
   90% confidence this time.
