---
version: alpha
name: Streak Finder
description: Retro-arcade dashboard for Apple Health streak discovery. Neon accents on deep purple (dark) or ink-on-cream (light), all-monospaced, sharp pixel-panel corners.
colors:
  # Dark mode (default mood)
  bg: "#0A0612"
  bgRaised: "#120A22"
  bgCard: "#1E1236"
  grid: "#2A1A4A"
  ink: "#F4ECFF"
  inkDim: "#A395C0"
  inkFaint: "#4A3D6B"
  # Light mode
  bgLight: "#F5F2FF"
  bgRaisedLight: "#FFFFFF"
  bgCardLight: "#EDE8FC"
  gridLight: "#D8D0EE"
  inkLight: "#120824"
  inkDimLight: "#554670"
  inkFaintLight: "#B0A0CC"
  # Accents (dark / light pairs)
  lime: "#C8FF00"        # steps
  limeLight: "#8AAA00"
  magenta: "#FF2D95"     # exercise / intensity
  magentaLight: "#CC2266"
  cyan: "#2DD4FF"        # stand
  cyanLight: "#0099BB"
  amber: "#FFB020"       # active energy
  amberLight: "#CC7A00"
  red: "#FF3B50"         # at-risk / heart rate
  redLight: "#CC2233"
  # Metric-specific (carried inside screenshots; do not introduce in marketing)
  flightsOrange: "#FF7A00"
  workoutCoral: "#FF8866"
  mindfulMint: "#7AFF9E"
  sleepBlue: "#5DA9FF"
  earlyOrange: "#FFA040"
  distancePurple: "#B088FF"
typography:
  family:
    primary: JetBrains Mono
    fallback: ["IBM Plex Mono", "Berkeley Mono", "SF Mono"]
    note: "All copy is monospaced. RetroFont.mono(_:weight:) scales every size by 1.25× in-app — the values below are the pre-scale point sizes used at callsites."
  bigNumber:
    fontFamily: JetBrains Mono Bold
    fontSize: 64pt
    fontWeight: 700
    note: "Hero metric value, e.g. '10114' on the home card."
  display:
    fontFamily: JetBrains Mono Bold
    fontSize: 32pt
    fontWeight: 700
  h1:
    fontFamily: JetBrains Mono Bold
    fontSize: 22pt
    fontWeight: 700
  h2:
    fontFamily: JetBrains Mono Bold
    fontSize: 18pt
    fontWeight: 700
  label:
    fontFamily: JetBrains Mono Medium
    fontSize: 14pt
    fontWeight: 500
    case: UPPERCASE
  body:
    fontFamily: JetBrains Mono Regular
    fontSize: 14pt
  caption:
    fontFamily: JetBrains Mono Regular
    fontSize: 11pt
rounded:
  card: 0
  button: 0
  pill: 0
  bezel: 0
  style: sharp
  note: "Streak Finder is corner-less. Every shape in the app is a Rectangle with a 2px stroke. Continuous-rounded corners do not belong here."
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  xxl: 24px
  xxxl: 32px
components:
  pixelPanel:
    background: "{bgRaised}"
    border: "{inkFaint}, 2px"
    rounded: 0
    note: "The base container for every card in the app. PixelPanelStyle in Theme.swift."
  retroGlow:
    primaryShadow: "{accent}.opacity(0.6), radius 14, blur"
    offsetShadow: "{bg}, radius 0, x +3, y +3"
    note: "Soft accent glow underneath, hard offset of the background color on top — gives the CRT 'click' feel."
  heroMetricCard:
    background: "{bgRaised}"
    border: "{accent}, 2px"
    glow: retroGlow({accent})
    rounded: 0
    valueFont: bigNumber
    valueColor: "{accent}"
    labelFont: label
    labelColor: "{inkDim}"
  metricToggleRow:
    background: "{bgRaised}"
    border: "{inkFaint}, 2px"
    height: ~44px
    iconColor: "{accentForMetric}"
    iconStyle: SF Symbol or pixel sprite, 18pt
    labelFont: label
    toggleStyle: pixel-block knob (no system Toggle)
  heatmapCell:
    states:
      met: "{accentForMetric}"
      missed: "{inkFaintLight} (light) / {inkFaint} (dark)"
      noData: "{bgCard}"
      today: "1.5px {cyan} outline"
    rounded: 0
    note: "Calendar heatmap on every metric detail screen. Rows = days of week, cols = weeks."
  navTab:
    style: full-width labeled row, no rounding
    underline: 2px accent on active
streak:
  heroGradient:
    - "{lime}"
    - "{magenta}"
    note: "Used sparingly — the 'streak alive' visual moment."
---

## Overview

Streak Finder is a **retro arcade dashboard**. Imagine a CRT terminal that happens to be a habit tracker: monospaced everywhere, sharp 2px panel borders, neon accents on deep purple in dark mode (the default mood), ink-on-cream in light mode. Every metric gets its own neon — lime for steps, magenta for exercise, cyan for stand, amber for energy. The user's job is to keep the number going up; the app's job is to make that number feel like a high score.

## Colors

Three layers: surfaces (purple/cream), ink (text), and metric accents (neon).

**Surfaces**
- **bg / bgLight:** Canvas. Deep purple `#0A0612` in dark, cream `#F5F2FF` in light.
- **bgRaised / bgRaisedLight:** Cards. One step up — `#120A22` / `#FFFFFF`.
- **bgCard / bgCardLight:** Inset surfaces (heatmap cells, recessed wells). `#1E1236` / `#EDE8FC`.
- **grid / gridLight:** Hairlines and decorative grid backgrounds. `#2A1A4A` / `#D8D0EE`.

**Ink**
- **ink:** Primary text. Near-white lavender in dark `#F4ECFF`; deep purple `#120824` in light.
- **inkDim:** Secondary text. Muted purple — `#A395C0` dark, `#554670` light.
- **inkFaint:** Borders and divider hairlines. `#4A3D6B` dark, `#B0A0CC` light.

**Metric accents (the neons)**

Each metric has a fixed accent, dark + light variants paired:

| Metric | Dark | Light |
|---|---|---|
| Steps | `#C8FF00` lime | `#8AAA00` |
| Exercise | `#FF2D95` magenta | `#CC2266` |
| Stand | `#2DD4FF` cyan | `#0099BB` |
| Active Energy | `#FFB020` amber | `#CC7A00` |
| Heart / At-risk | `#FF3B50` red | `#CC2233` |
| Workouts | `#FF8866` coral | (same) |
| Mindfulness | `#7AFF9E` mint | `#2A9955` |
| Sleep | `#5DA9FF` blue | `#0D5599` |
| Distance | `#B088FF` purple | `#7044CC` |
| Flights | `#FF7A00` orange | `#CC5500` |

These appear in the screenshots — leave them untouched. Marketing chrome should only borrow **one** accent per frame (see BRIEF §3).

## Typography

Everything is **JetBrains Mono**. No system fonts, no sans-serif fallback for display copy. The monospaced feel is the brand.

- **bigNumber:** 64pt Bold — hero metric on the home card (`10114`).
- **display:** 32pt Bold — onboarding headlines, paywall titles.
- **h1:** 22pt Bold (`.title2` slot) — section headers like `▮ OTHER STREAKS · 4 ACTIVE`.
- **h2:** 18pt Bold — card titles like `STEPS`, `EXERCISE`.
- **label:** 14pt Medium, UPPERCASE — toggle row labels, button text.
- **body:** 14pt Regular — settings descriptions, help text.
- **caption:** 11pt Regular — metadata, chart annotations like `8 days streak`.

Numeric values lean on the monospaced tabular-figure default. No need for a separate `monospacedDigit()` call — the whole family is already monospaced.

## Corner Radii

**There are none.** Every container is a hard-edged Rectangle with a 2px stroke (`PixelPanelStyle`). Continuous-rounded corners do not appear in this app. If you find yourself reaching for `.cornerRadius(_)` or `RoundedRectangle(cornerRadius:)`, stop — use `Rectangle().stroke(..., lineWidth: 2)` instead.

The single exception: iOS pushes a native rounded corner on the device frame itself. That's the device, not us.

## The pixel-panel motif

Two modifiers in `Theme.swift` define the look:

```swift
.pixelPanel(color: Theme.retroInkFaint, fill: Theme.retroBgRaised, lineWidth: 2)
.retroGlow(Theme.retroLime, radius: 14)
```

- `pixelPanel` = a hard-edged rectangle behind the content with a 2px border. Used on every card.
- `retroGlow` = a soft accent-color shadow layered with a `+3 / +3` offset hard shadow of the background. Together they create the "CRT bezel click" effect — the panel feels physically pressed into the canvas.

The marketing device-frame treatment in BRIEF §2.4 is a direct transcription of `retroGlow` into the App Store frame chrome.

## Icons

Mix of SF Symbols and tinted glyphs. Key symbols seen in the screenshots:

- `figure.walk` — Steps
- `figure.run` — Exercise
- `figure.stand` — Stand
- `flame.fill` — Active Energy (orange/amber glow)
- `figure.strengthtraining.traditional` / national-flag glyph — Workouts (the Canadian flag visible in raw_01 is a real workout-type indicator, not decoration — keep it)
- `bed.double.fill` — Sleep
- `figure.mind.and.body` — Mindfulness
- `arrow.right` — "Find More Streaks" affordance
- `gearshape.fill` — Settings

## Do's and Don'ts

- **Do** rotate one neon accent per frame in marketing chrome. Lime first, then alternate.
- **Do** keep every container hard-cornered with a 2px stroke. The pixel-panel look is non-negotiable.
- **Do** use JetBrains Mono for all headline + sub-copy. Fall back only to another mono.
- **Do** preserve all in-screenshot pixels exactly — including status-bar times, "TODAY" markers, and real demo numbers like "10114 steps" and "2 days streak".
- **Don't** introduce gradients in marketing chrome beyond what already exists inside the screenshots. The streakGradient (lime → magenta) is reserved for in-app use.
- **Don't** add continuous-rounded corners anywhere. Pills, capsules, soft cards — all wrong for this app.
- **Don't** introduce a sans-serif. Headlines are monospaced or they're off-brand.
- **Don't** apply a soft drop shadow to the device frame — use the hard offset shadow from §2.4 of BRIEF.
- **Don't** stack neon accents in the same frame. One emphasis color per headline.
