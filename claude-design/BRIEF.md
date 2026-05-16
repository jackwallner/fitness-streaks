# Streak Finder — App Store Preview Frames

> **Audience:** Claude Design
> **Deliverable:** 5 marketing preview frames for the App Store iPhone 6.9" slot. Each frame combines (a) one of the supplied raw screenshots inside an iPhone device frame, (b) a short headline + sub-copy band, and (c) brand-consistent background art.
> **Source screenshots:** `./screenshots/raw_*.png` (iPhone captures, 1284 × 2778).

---

## 0. CRITICAL — Output dimensions (this is where last time went wrong)

**Every PNG must be exactly 1290 × 2796 pixels.** Not 1024×1024. Not 832×1216. Not 1242×2688. Not a generic model-default canvas.

- Width: **1290 px**, Height: **2796 px**, PNG, sRGB color profile.
- This is the App Store Connect iPhone 6.9" display slot — the same slot accepts 1320 × 2868, but pick **one** dimension and stay there. Use **1290 × 2796** for this set.
- File size **≤ 8 MB** per PNG (App Store Connect hard limit).
- Aspect ratio is 1290:2796 ≈ 0.4614. If the renderer can only emit square or smaller canvases, render at 2× (2580 × 5592) and downsample, or compose in tiles — **never upscale a smaller PNG with bicubic/AI upscaling, the device frame will alias.**
- The source screenshots are 1284 × 2778. That is a ~0.5% scale to fit inside the device frame — imperceptible. Do not stretch them disproportionately.
- After export, verify with `file *.png` or `sips -g pixelWidth -g pixelHeight *.png`. If any frame is not exactly 1290 × 2796, re-render — do not let it ship.

---

## 1. Product One-Liner

**Streak Finder** mines Apple Health history on-device and surfaces fitness streaks the user has *already* built — steps, exercise minutes, stand hours, workouts, mindfulness, sleep, distance, flights, active energy. The killer line is "you don't have to start from day one." It nudges the user at 7 PM if a tracked streak is at risk that day, and ships widgets + a watchOS complication so the count is always glanceable.

Audience: people who feel locked out of habit-tracking apps because day-one feels like a fresh failure. They already work out, walk, or sleep well some weeks — they just don't see it as momentum. They own an iPhone, often an Apple Watch, and care about data staying on-device.

Tone: **direct, confident, retro-arcade.** It's a dashboard for someone who likes seeing the number go up. Not clinical, not gamified-cutesy. No emojis. No hype words like "AI-powered" or "revolutionary."

---

## 2. Brand Visual System

Streak Finder is a **retro arcade dashboard**. Think CRT terminal meets habit tracker: neon accents on deep purple in dark mode, ink-on-cream in light mode, all-monospaced typography, **sharp pixel-panel corners** (continuous-rounded is wrong here). Marketing chrome should feel like an extension of the in-app aesthetic.

### 2.1 Color tokens (use exactly)

| Token | Hex (dark) | Hex (light) | Usage in frames |
|---|---|---|---|
| `bg` | `#0A0612` | `#F5F2FF` | Canvas behind the device frame |
| `bgRaised` | `#120A22` | `#FFFFFF` | Inset surfaces, optional band fill |
| `ink` | `#F4ECFF` | `#120824` | Headline body text |
| `inkDim` | `#A395C0` | `#554670` | Sub-copy text |
| `inkFaint` | `#4A3D6B` | `#B0A0CC` | Hairline borders, dividers |
| `lime` | `#C8FF00` | `#8AAA00` | Accent — steps, primary emphasis |
| `magenta` | `#FF2D95` | `#CC2266` | Accent — exercise, intensity |
| `cyan` | `#2DD4FF` | `#0099BB` | Accent — stand, calm tone |
| `amber` | `#FFB020` | `#CC7A00` | Accent — energy, urgency |
| `red` | `#FF3B50` | `#CC2233` | Accent — at-risk, alert |

**Rotate one accent per frame** — do not stack accents. The chosen accent colors the emphasis word in the headline and (optionally) a thin 2px border on the device frame. The other accents only appear *inside* the screenshot, untouched.

No gradients in marketing chrome other than what's already inside the screenshots. No drop shadows on the device frame **other than** the signature offset hard-shadow described in §2.4.

### 2.2 Type

- **Headline:** **JetBrains Mono Bold**, 84–96pt at 1290 px width. Tracking 0 to -10. Two lines max — break the line manually, don't rely on word-wrap.
- **Sub-copy:** JetBrains Mono Medium, 32–38pt. One line preferred, two max.
- One **accent-colored emphasis phrase** per headline. Everything else uses `ink`. Inverted on dark band: everything in `ink` (light variant `#F4ECFF`), emphasis in the chosen accent.
- If JetBrains Mono is unavailable, fall back in this order: IBM Plex Mono Bold → Berkeley Mono → SF Mono Bold. Do **not** fall back to a non-mono font; the monospaced look is load-bearing.
- All-caps is fine for short headlines (≤4 words). Mixed-case for anything longer.

### 2.3 Layout grid

Two-zone vertical composition. Copy band on top for frames 1, 2, 4; copy band on bottom for frames 3 and 5 so the rhythm varies.

```
┌─────────────────────────┐
│  COPY BAND (~26% h)     │  ← headline (2 lines) + sub-copy
│  Streaks you already    │
│  ▶ built.               │
├─────────────────────────┤
│                         │
│   DEVICE FRAME          │  ← screenshot inside black iPhone shell
│   (centered, ~72% h)    │     6px gap between shell and inner screen,
│                         │     sharp offset shadow (see §2.4)
│                         │
└─────────────────────────┘
```

Band fill options:
- **Light band:** `bg` light (`#F5F2FF`), headline in `ink` light (`#120824`).
- **Dark band:** `bg` dark (`#0A0612`), headline in `ink` dark (`#F4ECFF`).
- Match the band to the screenshot's mode when possible (light screenshot → light band, dark screenshot → dark band) so the device frame doesn't fight its container.

### 2.4 Device frame & "pixel panel" signature

The in-app aesthetic uses sharp 2px panel borders with a 3px offset hard shadow (the `retroGlow` modifier). Carry that into the device frame:

- iPhone 17 Pro shell, black titanium, Dynamic Island as-is, no hand mockup.
- **No soft drop shadow.** Instead: a 2px stroke in the frame's accent color at 30% opacity, offset by a hard `+3px / +3px` shadow in `bg` (no blur). This makes the device "click into" the canvas like a CRT bezel.
- Optional pixel-panel chrome line: a 2px hairline rule under the copy band in `inkFaint`. Used on frames 1 and 4.

### 2.5 Optional background motif

Across the 5 frames, **frames 1, 3, and 5** may include a subtle background grid — 2px `inkFaint` lines at 48px spacing, 8% opacity. This echoes `Theme.retroGrid` from the app. Frames 2 and 4 leave the canvas flat. **Do not** introduce starbursts, glows, motion lines, sparkle particles, or sportsbook-style chrome.

---

## 3. Frame-by-Frame Brief

All 5 frames are mandatory. Order matters — frame 1 is the App Store hero (visible above the fold on every product page).

### Frame 1 — The Hero / Streaks You Already Built
- **Asset:** `raw_01_hero_light.png` (Streak Finder home tab in light mode — STEPS hero card showing 10,114 / 8 days streak, plus Workouts, Exercise, Active Energy, Stand cards underneath)
- **Headline:** `Streaks you've` / `already built.`
- **Sub-copy:** `Mine your Apple Health history. Find the momentum you didn't know you had.`
- **Emphasis:** `already built.` in `lime` (`#8AAA00` on light band).
- **Layout:** Light band on top. Background grid on. Device frame stroke in `lime` at 30%.

### Frame 2 — Detail + Calendar Heatmap
- **Asset:** `raw_02_detail_heatmap.png` (Steps detail screen in dark mode — 209 steps today, 2 days streak / 25 best days, 30-day calendar heatmap with MET / MISSED / NO DATA legend, CURRENT 2 / RECORD 25 / RATE 53% stat row)
- **Headline:** `Every day` / `you showed up.`
- **Sub-copy:** `Calendar heatmaps for every metric. 30 days, 90, 6 months, a year.`
- **Emphasis:** `showed up.` in `lime` (`#C8FF00` on dark band).
- **Layout:** Dark band on top. No background grid (the heatmap is dense — keep the canvas calm). Device frame stroke in `lime` at 30%.

### Frame 3 — Retro Dark Mode (visual identity moment)
- **Asset:** `raw_03_hero_dark.png` (same home tab in dark mode — neon lime/magenta/cyan/amber on deep purple)
- **Headline:** `Built like an` / `arcade dashboard.`
- **Sub-copy:** `Neon, monospaced, unapologetically retro. Light mode too if you'd rather.`
- **Emphasis:** `arcade dashboard.` in `magenta` (`#FF2D95` on dark band).
- **Layout:** Dark band on **bottom** (screenshot leads). Background grid on. Device frame stroke in `magenta` at 30%.

### Frame 4 — Calibration / Pick Your Intensity
- **Asset:** `raw_04_calibrate.png` (Settings screen in light mode — Appearance toggle, Intensity picker showing SUSTAINED / CHALLENGING / LIFE CHANGING, Recalibrate All Goals button, Discovery Window 7/30/90/180/365)
- **Headline:** `Tune the bar` / `to your life.`
- **Sub-copy:** `Sustained, challenging, or life-changing — pick the streak you actually want to keep.`
- **Emphasis:** `to your life.` in `magenta` (`#CC2266` on light band).
- **Layout:** Light band on top. No background grid. Device frame stroke in `magenta` at 30%.

### Frame 5 — Smart Reminders + Metrics
- **Asset:** `raw_05_metrics.png` (Settings screen in dark mode — At-Risk Reminder toggle on, reminder time 10:00 PM, Metrics Tracked list with 10 colored toggles: Steps, Exercise, Stand, Active Energy, Workouts, Mindfulness, Sleep, Distance, Flights, Intensity, Cardio Minutes)
- **Headline:** `One nudge` / `before you drop it.`
- **Sub-copy:** `7 PM check-in if your streak is at risk. Track up to 11 metrics — or just the one.`
- **Emphasis:** `before you drop it.` in `amber` (`#FFB020` on dark band).
- **Layout:** Dark band on **bottom**. Background grid on. Device frame stroke in `amber` at 30%.

---

## 4. Hard Constraints

- ❌ **Do not retouch pixels inside the screenshot.** Crop only — every number, every label, every chip stays exactly as captured. The "209 steps" on frames 2 and 3, the "10,114 steps" on frame 1, the "2 days streak" — leave them. These are real demo data.
- ❌ No emojis, sparkles, motion lines, glow bursts, "WOW" effects, or sportsbook/promo styling.
- ❌ No medical claims. Do not write "healthy," "wellness program," "fitness coach," "doctor recommended," "clinically proven," or anything implying diagnosis or treatment. Streak Finder *observes* — it does not advise.
- ❌ No competitor names (Streaks, Strides, Habitica, Apple Fitness+, etc.).
- ❌ No Apple Health, HealthKit, Apple Watch, or App Store wordmarks/logos in the marketing chrome. The app uses these — the App Store frame doesn't need to badge them.
- ❌ No fake/marketing UI. Every pixel inside the device frame must come from the supplied screenshot.
- ❌ No more than one accent-colored emphasis phrase per headline.
- ❌ No "Available on the App Store" badge — App Store places that itself.
- ❌ **No rounded-continuous corners on marketing chrome.** This app is sharp-cornered. Pixel panels, not pill shapes. (The device frame itself has its native iPhone radius — that's fine.)
- ✅ One accent emphasis phrase per headline.
- ✅ Device frame uses the §2.4 sharp-offset shadow, not a soft drop shadow.
- ✅ Status bar in source screenshots ("6:37 / 9:15 / 9:16 / 9:18 / 10:01") is fine — leave alone. Do not normalize to 9:41.
- ✅ The "TestFlight" indicator visible at the top of `raw_04_calibrate.png` — **crop or paint over** with the screenshot's own status-bar background color. This is the only intra-screenshot edit allowed, and only for this single asset.

---

## 5. Output Specifications

- **Dimensions:** 1290 × 2796 px, PNG, sRGB. (See §0 — verify before shipping.)
- **Device shell:** iPhone 17 Pro, black titanium, Dynamic Island as-is.
- **Filename convention:** `appstore_preview_<NN>_<slug>.png`
  - `appstore_preview_01_hero.png`
  - `appstore_preview_02_heatmap.png`
  - `appstore_preview_03_dark.png`
  - `appstore_preview_04_calibrate.png`
  - `appstore_preview_05_reminders.png`
- **Safe zone:** Keep all headline text ≥ 80 px from any edge. Status-bar area inside the device frame doesn't count — that's the screenshot.
- **Export location:** `/Users/jackwallner/fitness-streaks/fastlane/screenshots/en-US/` (Fastlane picks these up via `scripts/upload-appstore-metadata.sh`).
- **Also provide:** one composite contact-sheet PNG (`appstore_preview_contact_sheet.png`) showing all 5 frames at 25% scale side-by-side, for quick review. The contact sheet doesn't need to hit 1290 × 2796 — a single landscape PNG ≤ 4000 px wide is fine.

---

## 6. Asset notes & gotchas

- All 5 raw captures are **1284 × 2778** PNGs (iPhone 6.5"/older 6.7"). Light upscale (~0.5%) to fit the 1290-wide canvas inside the device frame is fine. Do **not** crop content out.
- `raw_04_calibrate.png` has a **"◀ TestFlight" indicator** in the top-left status bar (visible because this capture was taken from a TestFlight build). Paint it out with the surrounding status-bar background, or crop it cleanly via the device frame's bezel — either way it must not appear in the final marketing frame.
- The "STEPS" hero card in raw_01 and raw_03 shows the same metric in light vs dark mode — this is intentional, it's the visual-identity pairing. Don't swap one for a different metric for variety.
- The 30-day calendar heatmap in raw_02 has a faint cyan "TODAY" marker on the Saturday cell — keep it visible, it's a real product detail.
- raw_05 shows the metric toggle list mid-scroll; the "DATA" section header is partially clipped at the bottom. Don't crop differently to "fix" it — the partial clip implies scrollability and is fine.

---

## 7. Reference files

| File | What it is |
|---|---|
| `reference/design-system.md` | Full in-app design system spec — palette, type, components, the pixel-panel motif |
| `reference/product-description.md` | App Store description and tone cues for voice calibration |
| `screenshots/raw_*.png` | Source captures for each frame, named to match §3 |
