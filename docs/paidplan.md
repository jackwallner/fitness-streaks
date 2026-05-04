# Implementation Plan: Grace Days as a Paid Feature (FitnessStreaks Pro)

This document provides a fully exhaustive architectural and UI plan to transition "Grace Days" into an optional paid capability via In-App Purchases (StoreKit 2). 

## 1. StoreKit Integration (The Foundation)
We need a robust way to manage subscriptions and entitlements using Apple's modern StoreKit 2 framework.

*   **Create `StoreKitService.swift`**:
    *   An `@Observable` (or `ObservableObject`) singleton responsible for the purchase lifecycle.
    *   **Responsibilities**:
        *   Fetch products (`Product.products(for:)`) on initialization.
        *   Initiate purchases (`Product.purchase()`).
        *   Listen for background transaction updates (`Transaction.updates` via an async task) to catch renewals or cancellations outside the app.
        *   Provide a synchronous `isPro` boolean state to the rest of the app.
*   **Local Testing Environment**:
    *   Create a `FitnessStreaks.storekit` configuration file in Xcode.
    *   Define your test products (e.g., `com.fitnessstreaks.pro.monthly`, `com.fitnessstreaks.pro.yearly`, or a lifetime unlock).
    *   Enable this configuration in the Xcode scheme to test purchases locally.

## 2. Logic & Model Gating (The Enforcer)
The `StreakStore` and `StreakSettings` dictate when a streak breaks and when a grace day is applied. We must gate the *consumption* of grace days, but let users accrue them for free as a marketing mechanic.

*   **Update `StreakSettings.swift`**:
    *   Modify `consumeGraceDay()` to accept `isPro: Bool` as an argument (or access the `StoreKitService` directly).
    *   If `!isPro`, `consumeGraceDay()` must return `false` immediately, even if `earnedGraceDays > 0`.
    *   *Strategic Note:* We will continue to let `awardGraceDays(from:)` run for free users. This banks premium currency for them, acting as a massive upsell ("You have 3 Grace Days banked! Upgrade to Pro to use one!").
*   **Update `StreakStore.swift`**:
    *   In the `handleBreaks(previous:fresh:hourly:history:)` method, where `settings.consumeGraceDay()` is called, ensure it respects the `isPro` state.
    *   Because `StreakStore` skips engine computation on `watchOS` (and simply reads the resulting `SnapshotStore`), we **do not** need to implement StoreKit transaction verification on the Apple Watch. The iPhone will correctly determine if a streak was preserved by a Grace Day and sync the final `Streak` models to the Watch.

## 3. UI & Upsell Workflows (The Conversion)
The user needs to understand what Grace Days are and be prompted to buy Pro at the high-intent moment a streak breaks.

*   **Create `ProPaywallView.swift`**:
    *   A beautifully designed full-screen sheet matching the Retro/Pixel aesthetic.
    *   **Hero Feature**: "Grace Days" - Explain how they are earned (1 per 30 days) and how they automatically save streaks.
    *   Display dynamic pricing fetched from `StoreKitService`.
    *   Include mandatory Apple links (Terms of Service, Privacy Policy, Restore Purchases).
*   **Update `SettingsView.swift`**:
    *   Locate the Grace Days configuration area.
    *   If `!isPro`:
        *   Show the toggle as "Locked" with a Pro badge/padlock.
        *   Show their accrued balance: *"You have earned X Grace Days. Unlock Pro to enable them."*
        *   Tapping the area presents the `ProPaywallView`.
*   **High-Intent Contextual Upsell (`DashboardView` / Broken Streak Sheet)**:
    *   Currently, when a streak breaks, the user sees a banner or sheet.
    *   If `!isPro` and a streak just broke, hijack that moment: *"Oh no! Your 45-day Steps streak broke. Unlock FitnessStreaks Pro right now to use one of your banked Grace Days and restore it."*
    *   This is the highest converting moment in any habit tracker.

## 4. Administrative (App Store Connect)
*   Create the corresponding In-App Purchases (Auto-renewable subscriptions or Non-consumable lifetime) in App Store Connect.
*   Ensure the Product IDs match exactly what is coded in `StoreKitService`.
*   Ensure your Paywall includes the standard App Store review requirements (EULA link, privacy policy link, clear pricing terms).
*   Submit the IAPs for review along with the app update.
