# Design

Visual system of the SubHelm marketing site (`landing/`), captured from the shipped code.

Stack: Astro 7, static output. Tokens live in `src/styles/global.css`; everything
else is a scoped `<style>` block inside its component.

## Theme

Single light theme, warm paper rather than white. Scene: someone at a kitchen
table on a Sunday, working out where the money goes; the page should feel like a
clear statement on good paper, not a dashboard. One section inverts to near-black
so the privacy claim lands as its own room.

## Color

| Token | Value | Role |
|---|---|---|
| `--raised` | `#fff` | Floating notification cards, assistant chips |
| `--cell` | `#FBFAF8` | Hairline-grid cells |
| `--paper` | `#F4F3EF` | Page |
| `--band` | `#EFEEE9` | Alternating full-width bands, ticker, closing CTA |
| `--device` | `#0B0B0B` | Phone bezel |
| `--ink` | `#0F1613` | Primary text, dark buttons |
| `--ink-dim` | `#5C6B66` | Secondary text (5.0:1 on paper) |
| `--accent` | `#0D9488` | App-icon teal: display italics, fills, rules |
| `--accent-ink` | `#0A6E66` | Accent as small text: links, kickers (5.5:1 on paper) |
| `--accent-ink-hover` | `#085650` | Link hover |
| `--night` | `#0B120F` | Privacy section |
| `--night-ink` | `#EAF2EF` | Privacy section text |
| `--night-dim` | `#94AEA8` | Privacy section secondary (8.0:1) |
| `--night-accent` | `#5EEAD4` | Privacy section accent (12.8:1) |
| `--line-faint` / `--line-soft` / `--line` / `--line-strong` | `rgba(15,22,19,.07/.09/.10/.12)` | Hairlines |
| `--night-line` | `rgba(234,242,239,.10)` | Hairlines on night |

Strategy: **Restrained**, on purpose. The paper carries the surface and teal
appears only as accent; the one saturated moment is the inverted privacy section.

**The two-teal rule.** `--accent` is 3.2:1 on paper, which clears AA only at
display sizes. Use it for type ≥24px, fills and rules. Anything small and
textual takes `--accent-ink`. Getting this wrong is the site's one recurring
accessibility trap.

## Typography

- One family: **Instrument Sans Variable**, self-hosted via `@fontsource-variable`
  (weight axis + italic), so the page makes no third-party request.
- Weights 400–700. Hierarchy is scale and italic, not family contrast.
- Display: 600 weight, tight tracking (`-.028em` to `-.032em`), line-height 1.02–1.07.
  Hero `clamp(44px, 4.9vw, 62px)`; section heads `clamp(30px, 3.6vw, 46px)` to
  `clamp(34px, 4.2vw, 56px)`; privacy statement `clamp(36px, 4.6vw, 62px)`.
- The hero cap is deliberate: above 62px the headline outgrows its column and the
  intended two-line break collapses.
- Body 17px/1.55; section leads 17.5–19px; kickers 12.5px, `.14em`, uppercase, 600.
- One italic word per headline, in accent. It is the site's only typographic
  flourish; keep it to a single word.

## Layout

- `--wrap: 1180px`, `--gutter: 28px`.
- Section rhythm `clamp(72px, 9vw, 124px)`; the privacy section gets
  `clamp(84px, 10vw, 140px)`.
- Hairline-separated composite blocks instead of cards: 1px gaps over `--line`
  with one 22px outer radius (`.hairline-grid`).
- Hero is asymmetric `1.12fr / .88fr` above 900px; the copy column needs the surplus.
- Feature rows alternate left/right above 700px. Copy always leads in the DOM so the
  collapsed mobile order stays text-then-image.
- Grids use `repeat(auto-fit, minmax(…, 1fr))` throughout: no width breakpoints.

## Motion

- Easing `cubic-bezier(.16,1,.3,1)`; durations .2s–.9s.
- Two entrance animations only (`rise` on the hero copy and stage, staggered 0.12s),
  a 6s `floaty` bob on the two notification cards, and hover transitions.
- No scroll-triggered reveals, no pinning, no parallax. The old site's pinned
  showcase cost ~3000px and hid the product entirely on mobile.
- `prefers-reduced-motion`: all animation and transition off, smooth scroll off.

## Components

`src/components/` holds Header, Hero, Ticker, HowItWorks, Showcase, Features,
Privacy, Faq, FinalCta, Footer, plus two primitives:

- **AppStoreBadge**: ink pill, Apple glyph + two-line label, lifts 2px on hover.
  The page's one true CTA, used twice (hero, closing). Never restyle per placement.
- **Phone**: `<Image>` in a `--device` bezel. Default is the full hero device;
  `crop` gives the open-bottomed variant with a `mask-image` fade at 74%.
- **Spec rows** (privacy): a `<dl>` of label + oversized accent value. Reads as a
  plain claim, which is the point.

## Authoring note

Astro drops a newline that sits directly against an inline tag boundary, so
`collect\n<strong>x</strong>` renders as `collectx`. Keep the space on the same
line as the tag. This bit the privacy page in seven places.

## Voice in UI copy

Short declarative claims; plain words a person can check ("Accounts required /
None"). No em dashes; commas, colons, semicolons or periods instead.
