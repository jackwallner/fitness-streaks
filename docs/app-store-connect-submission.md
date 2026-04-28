# App Store Connect Submission Guide: Streak Finder

This document contains all the fields and marketing copy required for the App Store Connect submission of **Streak Finder**.

---

## 1. App Information

- **App Name:** `Streak Finder`
- **Subtitle:** `Discover Your Fitness Streaks` (or `Retro Pixel Fitness Tracker`)
- **Primary Category:** `Health & Fitness`
- **Secondary Category:** `Lifestyle`
- **Privacy Policy URL:** `https://jackwallner.github.io/fitness-streaks/privacy-policy.html`
- **Primary Language:** `English`
- **Bundle ID:** `com.jackwallner.streaks`
- **SKU:** `STREAK_FINDER_001`

---

## 2. Version Information (v1.0.0)

### Promotional Text
> *Retro vibes. Modern health. Zero effort.*

### Description
Discover the fitness streaks you’ve already built—automatically.

Streak Finder scans your Apple Health history to uncover hidden patterns and consistent wins you might have missed. No manual logging. No intrusive tracking. Just pure data, beautifully visualized in a signature retro pixel aesthetic.

**Why Streak Finder?**
- **Automatic Discovery:** Our engine mines your HealthKit history (steps, workouts, stand time, and more) to find your existing momentum.
- **Retro Aesthetic:** A classic 8-bit interface that makes your fitness goals feel like an arcade game you’re actually winning.
- **100% Private:** Your data never leaves your device. No cloud, no accounts, no trackers. Just you and your health.
- **Smart Reminders:** Get "at-risk" nudges only when your current hero streak is in danger of breaking.
- **Widgets & Complications:** Keep your fire burning right on your Home Screen or Apple Watch face.

*Requires Apple Health (HealthKit) access.*

### Keywords
`fitness,streaks,health,steps,workout,pixel,retro,tracker,healthkit,momentum,apple health,daily,habits,pedometer`

### Support URL
`https://github.com/jackwallner/fitness-streaks` (or your support email: `mailto:jackwallner@gmail.com`)

### Marketing URL
`https://github.com/jackwallner/fitness-streaks`

---

## 3. App Review Information

- **Contact Information:**
  - First Name: `Jack`
  - Last Name: `Wallner`
  - Email: `jackwallner@gmail.com`
- **Demo Account:** `Not Required` (The app uses local HealthKit data and requires no login).
- **Notes for Reviewer:**
  > This app is a local-only utility for visualizing Apple Health data. It requires HealthKit permissions for Read-Only access to various activity types (Steps, Exercise, Stand Hours, etc.) to calculate and display streaks. There is no server-side component or network activity.

---

## 4. App Privacy (Data Types)

In the "App Privacy" section, select **"Data Not Collected"** as the app does not transmit any data off-device.

If you must specify data types read (even if not collected):
- **Health & Fitness:** Not Collected
- **Identifiers:** Not Collected

---

## 5. Visual Assets

- **App Icon:** Already included in the build (`AppIcon-1024.png`).
- **Screenshots:**
  - **iPhone:** Capture the DashboardView, OnboardingView, and a DetailView showing the Calendar Heatmap.
  - **Apple Watch:** Capture the WatchTodayView showing the current hero streak.
