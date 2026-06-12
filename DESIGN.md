# Design

Visual system of the SubPilot marketing site (`landing/`), captured from the shipped code.

## Theme

Single dark theme. Near-black with a green-teal tint (not neutral black), lit by teal radial glows. Scene: someone on their phone at night, annoyed about money; the page answers with calm confidence, not alarm. Subtle SVG grain overlay (5% opacity) keeps large dark fields from banding.

## Color

| Token | Value | Role |
|---|---|---|
| `--bg` | `#060A09` | Page background (teal-tinted near-black) |
| `--bg-raise` | `#0C1413` | Raised surfaces, pills |
| `--ink` | `#EAF6F3` | Primary text (teal-tinted near-white) |
| `--ink-dim` | `#85A09A` | Secondary text |
| `--teal` | `#14B8A6` | Brand mid |
| `--teal-bright` | `#2DD4BF` | Accent text, highlights, hovers |
| `--teal-deep` | `#0D9488` | Brand deep (matches app icon) |
| `--line` | `rgba(234,246,243,.08)` | Hairlines, grid borders |

Strategy: **Committed** dark teal. The teal family carries identity through glows, accents and selection; never use pure `#000`/`#fff`. Brand-coloured dots (Netflix red etc.) are allowed inside product-mimicking UI chips only.

## Typography

- Display: **Anton**, uppercase, weight 400, tight line-height (0.94–1.0), used huge (`clamp(54px, 7.6vw, 104px)` hero; up to 118px on the privacy statement; 228px outlined footer mark).
- Body/UI: **Archivo**, 400–700. Body 17px/1.6; subheads 18–19px; labels 11–13.5px with wide letter-spacing (`.12em–.22em`) and uppercase for kickers/tickers.
- Hierarchy comes from extreme scale contrast between Anton display and small spaced labels; body text stays modest.

## Layout

- Single column flow, `max-width: 1160px`, 28px gutters.
- Sections breathe: 130px vertical padding (90px mobile); the privacy statement gets 170px.
- Hairline-separated composite blocks instead of cards: stats band and feature grid are 1px-gap grids over `--line` with one 24px outer radius.
- Hero: asymmetric 1.12fr/.88fr split, copy left, tilted phone right with floating notification pills.

## Motion

- Easing: `cubic-bezier(.16,1,.3,1)` (expo-out) everywhere; durations .25s–1s.
- Patterns: masked line-rise for display type; fade+rise reveals on scroll (IntersectionObserver, one-shot); scroll-pinned 3-step phone showcase; cursor-following parallax on phone tilt and pills; magnetic CTA buttons; marquee ticker (28s linear).
- `prefers-reduced-motion`: all animation collapses, content shown immediately.

## Components

- **Store badge**: light pill (ink background, dark text), Apple glyph + two-line label, teal glow shadow on hover. The page's one true CTA, used twice (hero, closing).
- **Notification pill**: blurred raised chip with brand-dot, headline + dim small line. Mimics iOS notifications; floats with bob + parallax.
- **Stats band**: 3 hairline-separated cells, Anton number in teal-bright + small spaced caption.
- **Feature grid**: 6 hairline cells, spaced Anton index number, 18px bold head, dim body; cursor-tracking radial glow on hover.
- **Ticker**: uppercase Anton items separated by teal ✦, infinite scroll.
- **Footer mark**: giant outlined (text-stroke) wordmark, teal stroke on hover.

## Voice in UI copy

Short declarative claims; numbers as proof ("0 bytes of your data collected"). No em dashes; commas, colons, semicolons or periods instead.
