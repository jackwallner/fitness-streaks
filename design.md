---
version: alpha
name: Fitness Streaks Pro
description: Retro arcade tracker — neon magenta, pixel panels, dark mode.
colors:
  primary: "#f4ecff"
  secondary: "#a395c0"
  tertiary: "#ff2d95"
  neutral: "#0a0612"
  surface: "#120a22"
  on-primary: "#0a0612"
  accent-lime: "#c8ff00"
  accent-cyan: "#2dd4ff"
  accent-amber: "#ffb020"
typography:
  display:
    fontFamily: JetBrains Mono
    fontSize: 1.4rem
    fontWeight: 700
  h1:
    fontFamily: JetBrains Mono
    fontSize: 1.1rem
    fontWeight: 700
  body:
    fontFamily: JetBrains Mono
    fontSize: 0.85rem
    lineHeight: 1.5
  label:
    fontFamily: JetBrains Mono
    fontSize: 0.65rem
    fontWeight: 700
rounded:
  sm: 0px
  md: 0px
  lg: 0px
spacing:
  sm: 8px
  md: 14px
  lg: 18px
components:
  button-primary:
    backgroundColor: "#c8ff00"
    textColor: "#0a0612"
    rounded: 0px
    padding: 12px 18px
  card:
    backgroundColor: "#120a22"
    textColor: "#f4ecff"
    rounded: 0px
    padding: 14px
---
## Overview

A neon pixel-arcade system built for FitnessStreaks — dark backgrounds, sharp
zero-radius panels with 2px solid borders, and a single magenta accent driving
interaction. JetBrains Mono throughout for a terminal/tracker feel.

## Colors

- **Primary (`#f4ecff`):** Headlines and core text on dark surfaces.
- **Secondary (`#a395c0`):** Body copy, captions, metadata.
- **Tertiary (`#ff2d95`):** The sole interaction accent — reserve it for the
  selected product card, the PRO chip, and key highlights.
- **Neutral (`#0a0612`):** Screen background — page foundation.
- **Surface (`#120a22`):** Card and panel backgrounds — slightly raised from
  neutral.
- **Accent extras:** Lime (`#c8ff00`) for the purchase button only, cyan
  (`#2dd4ff`) for restore/legal links, amber (`#ffb020`) for status messages.

## Typography

- **display:** JetBrains Mono Bold 1.4rem
- **h1:** JetBrains Mono Bold 1.1rem
- **body:** JetBrains Mono Regular 0.85rem
- **label:** JetBrains Mono Bold 0.65rem

## Do's and Don'ts

- **Do** use Tertiary for exactly one action per screen — the selected card.
- **Do** let Neutral carry the composition — negative space is a feature.
- **Do** keep all corners sharp (0px radius) — the pixel aesthetic is load-bearing.
- **Don't** use gradients. This system is flat fills with solid 2px borders.
- **Don't** mix Tertiary with alternate accents for the same role; each accent
  has one job.
