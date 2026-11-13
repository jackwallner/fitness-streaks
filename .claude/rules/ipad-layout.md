---
paths:
  - "FitnessStreaks/**"
  - "project.yml"
---

# Streak Finder: iPad layout (2026-11-12)

The app is universal (`TARGETED_DEVICE_FAMILY: "1,2"`, all four iPad orientations
in `Info.plist`). Once a release ships with iPad support it cannot be removed, so
every screen has to look designed for iPad, not a stretched phone.

- Regular width (iPad, any rotation) reuses the iPhone Duo two-pane layout (see
  `iphone-duo.md`): tabs in the leading pane, streak detail or Settings in the
  trailing pane, split evenly with a 2 pt rule when there is no fold. Do not add a
  second iPad-only layout.
- Single-column screens that are not in a pane (onboarding) cap at
  `readableWidth()` (560 pt) and centre. Never let a column run full width.
- Sheets (paywall, trial offer, settings, pickers) stay plain `.sheet`; iPad
  presents them as form sheets. Keep their content width-safe.
- Cards, buttons and type keep their phone sizes. No extra labels or helper text
  on iPad.
- Health data may be absent on iPad (no Health store, no sensors): the empty and
  sparse states must read fine, not broken.
- Capture: `gh-sim launch --device "iPad Pro 13-inch (M5)"` with `--screen`
  args. `-ForceLandscape` (DEBUG) rotates after launch; `-PaywallSnapshot` shows
  the real sheets on iPad. Check portrait, landscape and a Split View size.
