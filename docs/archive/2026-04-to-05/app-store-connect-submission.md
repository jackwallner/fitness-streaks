# App Store Connect Submission Guide: Streak Finder (v1.0.1)

This document contains all the fields, marketing copy, reviewer notes, and IAP details required for the App Store Connect submission of **Streak Finder**. Copy-paste ready.

---

## 1. App Information

- **App Name:** `Streak Finder`
- **Subtitle:** `Discover Your Fitness Streaks`
- **Primary Category:** `Health & Fitness`
- **Secondary Category:** `Lifestyle`
- **Privacy Policy URL:** `https://jackwallner.github.io/fitness-streaks/privacy-policy.html`
- **Primary Language:** `English`
- **Bundle ID:** `com.jackwallner.streaks`
- **SKU:** `STREAK_FINDER_001`

---

## 2. Version Information (v1.0.1)

### Promotional Text
```
Never lose a streak. Pro alerts you before one slips and auto-saves it with a Grace Day when life happens. 7-day free trial.
```

### Description
```
Start building habits without starting from day one.

Streak Finder securely mines your Apple Health history to uncover the fitness streaks you've already built — and gives you the exact nudge you need to keep them alive.

There is nothing more motivating than realizing you're already on a winning streak. Whether you're closing your rings, hitting 10,000 steps, or prioritizing daily mindfulness, Streak Finder removes the friction of "starting over" by automatically tracking the momentum you already have.

KEY FEATURES:

* Auto-Discover Your Momentum
Instantly find active streaks across 9 key Apple Health metrics: Steps, Exercise Minutes, Stand Hours, Active Energy, Workouts, Mindfulness, Sleep, Distance, and Flights Climbed.

* Hero Streaks & Badges
Put your most important goal front and center with the Hero Streak view, and collect beautifully designed badges as your habits grow stronger.

* Calendar Heatmaps
Visualize your progress over time with stunning calendar heatmaps that make your daily consistency undeniable.

* Accountability Everywhere
Keep your goals at a glance with beautifully crafted iOS widgets for your Home Screen, Lock Screen, and StandBy mode.

* Apple Watch Ready
Check your streaks right from your wrist with a fully native watchOS app and rich complications.

* Smart Reminders
Never drop the ball. Get a gentle, automatic nudge at 7 PM if your Hero Streak is at risk of breaking that day.

* Fiercely Private (By Design)
Your health data is deeply personal, and it belongs to you. Streak Finder was built with a privacy-first foundation:
- Read-only Apple HealthKit access
- 100% on-device, local processing
- No user accounts or sign-ups required
- Zero network calls
- Zero analytics or tracking

FITNESSSTREAKS PRO
FitnessStreaks Pro ($29.99 lifetime, $14.99/yr, or $1.99/mo) unlocks Grace Days — automatic saves when you miss a day. Every plan includes a 7-day free trial.

Don't break the chain. Download Streak Finder today and keep your momentum going!
```

### Keywords
```
fitness,streaks,health,steps,workout,pixel,retro,tracker,healthkit,momentum,apple health,daily,habits,pedometer,streak tracker,habit tracker,health streaks,workout streaks,step counter streak,fitness goals,grace days
```

### What's New in This Version
```
Introducing FitnessStreaks Pro — Grace Days save your streaks automatically. 7-day free trial on all plans.
```

### Support URL
```
https://jackwallner.github.io/fitness-streaks/
```

### Marketing URL
```
https://jackwallner.github.io/fitness-streaks/
```

---

## 3. App Review Information

### Contact Information
- **First Name:** `Jack`
- **Last Name:** `Wallner`
- **Email:** `jackwallner@gmail.com`
- **Phone:** Leave blank (optional)

### Demo Account
`Not Required` — The app uses local HealthKit data and requires no login.

### Sign-In Required
No. No user accounts exist.

### Notes for Reviewer (copy-paste into the Review Notes field)
```
This app is a local-only utility for visualizing Apple Health data. It requires HealthKit permissions for Read-Only access to various activity types (Steps, Exercise, Stand Hours, etc.) to calculate and display streaks. There is no server-side component or network activity.

TESTING INSTRUCTIONS:
- To test the app, please ensure the testing device has some Apple Health data (such as steps or exercise minutes) so the app can successfully discover and display a streak.
- If no Health data is present, the app will display an empty state prompting the user to become active to start their first streak, which is the intended behavior for brand-new users.
- On first launch, you'll see a one-time coachmark tutorial overlay. Tap through it to reach the dashboard.

HEALTHKIT ACCESS:
- All processing is done strictly locally on the device using SwiftData.
- The app is completely read-only for HealthKit data.
- No user account, login, or internet connection is required.

NOTIFICATION PERMISSIONS:
- Notification authorization is only requested when the user explicitly toggles "AT-RISK REMINDER" in Settings, not on app launch. This complies with Apple's data minimization guidelines.

EXTERNAL LINK (Settings → Elsa Coach):
- The Settings view includes a link to e3fit.me for live 1-on-1 virtual personal training and nutrition coaching sessions.
- This falls under Guideline 3.1.1 "1-to-1 experiences" exemption, which allows apps to use purchase methods other than IAP for real-time 1-to-1 experiences such as fitness training.
- These are explicitly 1-on-1, live virtual sessions — not digital content or pre-recorded material.

PRIVACY POLICY:
- A direct link to the Privacy Policy is visible on the onboarding intro screen and the paywall screen.
- The app does not collect, transmit, or store any personal data off-device.
- App Privacy labels: "Data Not Collected" across all categories.

IN-APP PURCHASES:
- Three IAPs are attached to this version: Lifetime, Monthly, Yearly (see IAP section below for full details).
- A paywall review screenshot showing all three product cards, prices, trial terms, auto-renew disclosure, privacy policy link, and restore button is attached to each IAP.
- The restore button works without a sign-in screen using AppStore.sync().
- Free users retain the full base experience — only Grace Day consumption is gated behind Pro.
```

---

## 4. App Privacy (Data Types)

In the "App Privacy" section, set **"Data Not Collected"** as the app does not transmit any data off-device. StoreKit purchase receipts are handled entirely by Apple — we never receive, store, or process them.

Configure each data type as **"Not Collected"**:
- **Health & Fitness:** Not Collected
- **Identifiers:** Not Collected
- **Purchases:** Not Collected
- **Usage Data:** Not Collected
- **Diagnostics:** Not Collected

---

## 5. In-App Purchases — Complete Setup

### 5a. Prerequisites (One-Time Setup)

Before creating IAPs, verify in App Store Connect → **Business** → **Agreements, Tax, and Banking**:
- [ ] **Paid Apps** agreement is signed and **Active**
- [ ] Tax forms completed (US W-9 for US individual/sole prop)
- [ ] Bank account added for payouts
- [ ] Contact info filled (Senior, Financial, Technical, Legal — same person is fine)

### 5b. Subscription Group

Create in App Store Connect → **Subscriptions**:
- **Subscription Group Reference Name:** `FitnessStreaks Pro`
- This is what users see in iOS Settings → Subscriptions. Keep it consistent.

### 5c. Lifetime (Non-Consumable)

| Field | Value |
|---|---|
| Reference Name | `Pro Lifetime` |
| Product ID | `com.jackwallner.streaks.lifetime` |
| Type | Non-Consumable |
| Price | $29.99 USD (auto-fill rest of price matrix) |
| Display Name (en-US) | `FitnessStreaks Pro · Lifetime` |
| Description (en-US) | `Unlock Grace Days forever. Automatically save your streaks when life gets in the way. One-time purchase.` |
| Review Screenshot | Paywall screenshot (see §6) |
| Review Notes | `Non-consumable lifetime unlock. Tap the Lifetime card on the paywall, complete sandbox purchase, verify Settings → Grace Days shows the PRO chip. Screenshot attached shows full paywall with pricing, trial terms, restore button, and legal disclosures.` |

### 5d. Monthly (Auto-Renewable Subscription)

| Field | Value |
|---|---|
| Reference Name | `Pro Monthly` |
| Product ID | `com.jackwallner.streaks.monthly` |
| Subscription Group | FitnessStreaks Pro |
| Subscription Duration | 1 Month |
| Price | $1.99 USD/mo |
| Display Name (en-US) | `FitnessStreaks Pro · Monthly` |
| Description (en-US) | `FitnessStreaks Pro, billed monthly. Includes a 7-day free trial. Cancel anytime.` |
| Introductory Offer | New Subscribers → 7 Days → Free (P1D with 7 periods) |
| Review Screenshot | Paywall screenshot (see §6) |
| Review Notes | `Monthly auto-renewable subscription with 7-day free trial. Pricing clearly displayed on paywall: '$1.99/mo — 7 days free, then $1.99/month'. Auto-renew terms and cancellation policy visible on paywall. Restore button tested and working.` |

### 5e. Yearly (Auto-Renewable Subscription)

| Field | Value |
|---|---|
| Reference Name | `Pro Yearly` |
| Product ID | `com.jackwallner.streaks.yearly` |
| Subscription Group | FitnessStreaks Pro |
| Subscription Duration | 1 Year |
| Price | $14.99 USD/yr |
| Display Name (en-US) | `FitnessStreaks Pro · Yearly` |
| Description (en-US) | `FitnessStreaks Pro, billed yearly. Includes a 7-day free trial. Cancel anytime.` |
| Introductory Offer | New Subscribers → 7 Days → Free (P1D with 7 periods) |
| Review Screenshot | Paywall screenshot (see §6) |
| Review Notes | `Yearly auto-renewable subscription with 7-day free trial. Pricing clearly displayed on paywall: '$14.99/yr — 7 days free, then $14.99/year'. Best value tier shown with '$1.25/mo' monthly-equivalent breakdown. Auto-renew terms and cancellation policy visible.` |

### 5f. Attaching IAPs to the Version

In App Store Connect → **Distribution** → select the build → in the **In-App Purchases and Subscriptions** section, **add all three products**. They must be attached to the version to go through review together with the binary.

---

## 6. Required Paywall Screenshot

Apple requires a paywall screenshot (minimum 640×920, PNG) showing the full purchase flow. **Attach this same screenshot as the Review Screenshot for each IAP product.**

The screenshot must show:

- [ ] **All three product cards** (Monthly, Yearly, Lifetime) with prices visible
- [ ] **Subscription lengths** displayed ("1 Month", "1 Year")
- [ ] **Price per period** ($1.99/mo, $14.99/yr, $29.99 once)
- [ ] **Free trial terms** prominently shown ("7 days free")
- [ ] **Yearly monthly-equivalent** displayed ("$1.25/mo")
- [ ] **Auto-renew disclosure** text visible on-screen
- [ ] **Link to Terms of Service (EULA)** — uses Apple's standard EULA
- [ ] **Link to Privacy Policy** — visible and accessible
- [ ] **Restore Purchases button** — visible and accessible
- [ ] **Cancellation policy** — "Cancel anytime" or standard auto-renew text

**How to capture:** Build to iPhone simulator or device → tap "Unlock Pro" from Settings → screenshot ProPaywallView with all cards + legal block visible → resize to 640×920 minimum.

---

## 7. Sandbox Testing Checklist

Before submitting, create a sandbox tester (App Store Connect → **Users and Access** → **Sandbox Testers**) and verify on a real device:

- [ ] **Lifetime** purchase succeeds → `isPro = true`, paywall dismisses, Settings shows PRO chip
- [ ] **Monthly** purchase succeeds → free-trial copy shows "7 days free, then $1.99/mo"
- [ ] **Yearly** purchase succeeds → free-trial copy shows "7 days free, then $14.99/yr", monthly-equivalent displayed
- [ ] Force-quit + relaunch → Pro status persists
- [ ] **Restore Purchases** on fresh install → flips back to Pro
- [ ] Cancel sandbox subscription → wait for refresh → `isPro` flips to false
- [ ] **Switch tiers** → purchasing yearly after monthly upgrades correctly
- [ ] Free user keeps full base experience (only Grace Day consumption is gated)

The `.storekit` config in Xcode scheme covers most of this in simulator without sandbox setup.

---

## 8. Visual Assets

- **App Icon:** Included in the build (`AppIcon-1024.png`)
- **iPhone Screenshots (6.9" / 6.5" / 5.5"):**
  - Dashboard view showing hero streak and calendar heatmap
  - Onboarding intro screen (shows privacy policy link)
  - Streak detail view with badges and history
- **Apple Watch Screenshots (Ultra / Series):**
  - WatchTodayView showing current hero streak
  - Watch complication on a watch face

Screenshot files are in `Screenshots/` directory:
- `IMG_6816.png` through `IMG_6836.png` — app screenshots
- `paywall_3tier.png` — paywall review screenshot for IAP submission

---

## 9. Pre-Submission Sanity Checklist

### Build & Stability
- [ ] Archive builds succeed with no errors
- [ ] `ITSAppUsesNonExemptEncryption` is `<false/>` in ALL target Info.plists (iOS app, watch app, iOS widget, watch widget)
- [ ] All four targets have `PrivacyInfo.xcprivacy` manifests
- [ ] No crash with zero HealthKit data (fresh device / simulator)
- [ ] No crash with very large HealthKit data (heart rate query bounded)

### HealthKit
- [ ] HealthKit authorization flow completes on iOS 17+
- [ ] HealthKit authorization flow completes on watchOS 10+
- [ ] `HKWorkoutType` is included in read authorization types
- [ ] Stand Hours is auto-selected in onboarding core metrics

### Privacy & URLs
- [ ] Privacy policy URL loads from cellular (no Wi-Fi/cache): `https://jackwallner.github.io/fitness-streaks/privacy-policy.html`
- [ ] Support URL loads: `https://jackwallner.github.io/fitness-streaks/`
- [ ] Privacy policy link visible on onboarding intro screen
- [ ] Privacy policy link visible on paywall screen

### Pro & IAP
- [ ] All 3 IAP product IDs match between code and App Store Connect
- [ ] All prices shown correctly on paywall (pulled from live StoreKit)
- [ ] Free trial terms visible on subscription cards
- [ ] Auto-renew disclosure visible at bottom of paywall
- [ ] Restore Purchases button works without sign-in
- [ ] Pro status persists across force-quit + relaunch
- [ ] Free users retain all non-grace-day features

### UI & Accessibility
- [ ] Coachmark tutorial overlay appears on first launch
- [ ] Widgets update after Pro state changes
- [ ] Watch app does not flash onboarding on cold start
- [ ] Notification authorization only requested when user toggles reminders in Settings
- [ ] No `x-apple-health://` URL scheme calls remain (use Settings link or text instructions)

---

## 10. Submission Gotchas (Common Rejection Reasons)

| Issue | Status | Notes |
|---|---|---|
| Paywall locks free features | ✅ Safe | Only Grace Day consumption is gated |
| Restore button requires sign-in | ✅ Safe | Uses `AppStore.sync()`, no account needed |
| Free trial terms not shown | ✅ Safe | "7 days free, then $X" on each sub card |
| Subscription terms not visible on paywall | ✅ Safe | All in legal block at bottom |
| Prices hardcoded in UI | ✅ Safe | Uses `product.displayPrice` from StoreKit |
| Missing privacy policy at permission time | ✅ Safe | Link present on onboarding intro + paywall |
| Undocumented URL scheme | ✅ Safe | No private API usage |
| External digital purchase link | ⚠️ Noted | Elsa Coach link — cite Guideline 3.1.1 "1-to-1" exemption in review notes |

---

## 11. Post-Launch

- Monitor **Sales and Trends** → **Subscribers** for first conversions
- Reply to customer reviews mentioning Pro within 24h
- iOS Settings → Subscriptions is where users cancel — nothing to build
- Refunds are handled by Apple automatically; `Transaction.updates` fires and `refreshEntitlement()` flips `isPro` back to false
- Consider a win-back offer after 90 days for churned yearly subscribers

---

## 12. Changing Prices Later

Use App Store Connect → IAP → Pricing. Existing yearly subscribers are grandfathered for 60 days unless they explicitly accept the new price. Monthly subscribers see the new price at next renewal. Lifetime purchasers are always grandfathered. No code changes needed.

If raising prices, consider creating a new subscription tier and keeping existing subscribers on the old price to avoid mass cancellations.
void mass cancellations.
