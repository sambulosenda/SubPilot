# SubPilot — App Store Connect listing (Deutsch / de-DE)

Paste-ready German copy for the **Germany** storefront. Mirrors the structure of
`STORE_METADATA.md` (English). Character limits in parentheses; everything is
within limit. Voice is informal **du**, consistent with the in-app German
(`Localizable.xcstrings`).

> ⚠️ **Keywords below are reasoned German-ASO picks, NOT translations — but they
> have no volume/difficulty data yet.** Validate with `/keyword-research` on the
> **de** market before locking. German also complicates ASO via **compound
> words**: Apple may not split compounds (e.g. "Fixkosten" may not separately
> index "Kosten"), so the de-dup rule is fuzzier than in English — see notes.

---

## Name (30)

`SubPilot: Abo-Tracker` (21)

> Carries the #1 German term **Abo** (Apple stems → covers *Abos*). "Tracker" is
> a loanword Germans do search. Home-Screen name stays "SubPilot"
> (`CFBundleDisplayName`), unchanged.

## Subtitle (30)

Recommended: `Erinnerungen & Kostenüberblick` (30)

> Subtitle words ARE indexed. Carries **Erinnerung** (reminder), **Kosten**,
> **Überblick** — so these are kept OUT of the keyword field below. Mirrors the
> proven English subtitle's "reminders & budgeting" angle.

Alternatives (keep keyword field in sync if you switch):
- `Verlängerung & Fixkosten` (24) — swaps in the two most app-specific terms
  (renewal + recurring-costs); move *erinnerung* into keywords if you use this.
- `Nie wieder Abofallen` (20) — benefit-first, weaker keyword coverage.

## Promotional text (170 — editable any time, no new build)

`Alle Abos, deine Monatssumme und die nächste Verlängerung auf einen Blick – mit Erinnerung vor jeder Abbuchung, bevor aus der Testphase eine Kostenfalle wird.` (≈158)

## Keywords (100, comma-separated, no spaces — don't repeat words from name OR subtitle)

`abonnement,verwalten,verlängerung,kündigen,fixkosten,ausgaben,vertrag,abofalle,sparen,budget,manager` (100/100)

> Rationale:
> - **abonnement** — formal variant of "Abo"; different stem, worth the slot.
> - **verwalten / manager** — "Abos verwalten" / "Abo Manager" are common queries.
> - **verlängerung** — renewal; core concept, kept here since the subtitle uses
>   reminder+cost instead.
> - **kündigen** — high purchase-intent (covers *Kündigung* via the *künd-* stem).
> - **fixkosten / ausgaben / sparen / budget** — German budgeting frame.
> - **vertrag** — Germans think of subscriptions as *Verträge* (contracts).
> - **abofalle** — strongly German concept ("subscription trap"); differentiator.
> - Dropped for space (next to add after keyword-research): `haushaltsbuch`,
>   `kündigung`, `rechnung`, `probeabo`, `monatlich`, `zahlung`, `übersicht`.
> - **Compound caveat:** if validation shows Apple isn't indexing inside
>   compounds, consider standalone `kosten` here and a non-compound subtitle.

## Description (≤4000)

```
SubPilot behält alle deine Abos an einem Ort – und sorgt dafür, dass aus einer vergessenen Testphase nie eine böse Überraschung wird.

Füge ein Abo in Sekunden aus einem Katalog mit über 200 beliebten Diensten hinzu oder scanne einen Beleg – SubPilot liest die Details direkt auf deinem Gerät aus. Sieh deine echte monatliche Gesamtsumme in deiner eigenen Währung und erhalte vor jeder Verlängerung und vor dem Ende jeder Testphase eine Erinnerung, damit du rechtzeitig kündigen kannst.

DAS BEKOMMST DU

• Nächste Verlängerung auf einen Blick – Widgets für Home- und Sperrbildschirm zeigen die nächste Abbuchung und deine Monatssumme.
• Clevere Erinnerungen – ein Hinweis vor jeder Verlängerung oder bevor eine Testphase endet.
• Beleg-Scan – wird auf dem Gerät gelesen; nichts wird hochgeladen.
• Profile – halte private und berufliche Abos getrennt.
• Mehrere Währungen – sieh alles in eine Gesamtsumme umgerechnet.
• KI-Assistent auf dem Gerät – frag nach deinen Abos, unterstützt von Apple Intelligence (auf kompatiblen Geräten).
• iCloud-Sync – deine Daten werden privat zwischen deinen Geräten synchronisiert.

STANDARDMÄSSIG PRIVAT

Kein Konto. Keine Anmeldung. Keine Werbung, kein Tracking. Deine Abos bleiben auf deinem Gerät und werden nur über deine eigene private iCloud synchronisiert – wir können sie nicht sehen.

Übernimm mit SubPilot die Kontrolle über deine wiederkehrenden Kosten.

Datenschutzrichtlinie: https://gist.github.com/sambulosenda/744ff503ade4a19c0a4ac298160248f9
Nutzungsbedingungen (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

> **Required by 3.1.2(c)** — the standard-EULA + privacy links must appear in
> EVERY localized description too, not just English. Keep both lines on any edit.

## What's New (≤4000) — template; translate per release

```
Willkommen bei SubPilot 1.0.

• Verwalte alle deine Abos an einem Ort
• Widgets für Home- und Sperrbildschirm mit nächster Verlängerung und Monatssumme
• Erinnerungen vor Verlängerungen und vor dem Ende von Testphasen
• Beleg-Scan auf dem Gerät und ein Apple-Intelligence-Assistent
• Private iCloud-Synchronisierung zwischen deinen Geräten

Danke, dass du SubPilot ausprobierst – Feedback gerne an sambulosendas@gmail.com.
```

> The live German listing's What's New must match the *current* version. Update
> this for 1.1 when it ships.

## Screenshot caption overlays (German)

Mapped 1:1 to the **5 live English screenshots** (kicker + headline format).
Regenerate via the compose.py pipeline, capturing the frames on a
**German-language simulator** (so the in-app UI shows German) with **EUR** as the
preferred currency (so prices read €, not $).

| # | Live EN caption | German kicker | German headline |
|---|-----------------|---------------|-----------------|
| 1 | See what you really spend. | — | `Sieh, was du wirklich ausgibst.` |
| 2 | Stop / Surprise Charges & Forgotten Trials | `Schluss mit` | `bösen Überraschungen & vergessenen Testphasen` |
| 3 | Find / Where to Cut Back | `Finde` | `wo du sparen kannst` |
| 4 | Ask / About Your Spending | `Frag` | `nach deinen Ausgaben` |
| 5 | Scan / Receipts, No Bank Login | `Scanne` | `Belege – kein Bank-Login` |

> Three things to localize per screenshot: (a) caption overlay → above, (b)
> in-app UI in the frame → capture on a `de` simulator, (c) currency → set
> preferred currency to EUR before capturing so totals show € (live shots show $).
> Not blocking submission — ASC inherits the EN screenshots if you skip this —
> but localized screenshots materially lift conversion in-market.

## Listing fields (unchanged per-locale unless noted)

- **Category, age rating, support/privacy URLs:** same as the English listing.
- **Pricing:** App Store Connect shows € automatically in the de storefront —
  nothing to set in metadata.
- **Locale to add in ASC:** German (de-DE) under App Store → Localizations.
