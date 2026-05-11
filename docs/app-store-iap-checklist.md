# FitnessStreaks Pro — App Store Connect Launch Checklist

This is the exhaustive list of one-time setup steps to ship Pro on the App Store. Code is already wired; this doc covers everything that lives in App Store Connect, web, and submission metadata.

## 1. Paid Apps Agreement (one-time, blocks everything else)

App Store Connect → **Business** → **Agreements, Tax, and Banking**.

- Sign the **Paid Apps** agreement (this is separate from the Free Apps agreement).
- Fill in **Tax forms** (US W-9 if a US individual / sole prop, or W-8 BEN equivalent abroad).
- Add a **Bank account** for payouts.
- Add a **Contact** (Senior, Financial, Technical, Legal — same person is fine for an indie).

Status must read **Active** for both Paid Apps agreement and tax forms. **No In-App Purchases will appear in production until this is green.**

## 2. Create In-App Purchases

App Store Connect → **My Apps** → FitnessStreaks → **Monetization** → **In-App Purchases** (and **Subscriptions** for monthly/yearly).

### 2a. Lifetime (Non-Consumable)

| Field | Value |
|---|---|
| Reference Name | `Pro Lifetime` |
| Product ID | `com.jackwallner.streaks.lifetime` |
| Type | Non-Consumable |
| Price | $29.99 USD (let App Store Connect auto-fill the rest of the price matrix) |
| Display Name (en-US) | `FitnessStreaks Pro · Lifetime` |
| Description (en-US) | `Unlock Grace Days forever. Automatically save your streaks when life gets in the way. One-time purchase.` |
| Review Screenshot | Screenshot of the paywall on iPhone (see §5 for exact requirements) |
| Review Notes | "Non-consumable lifetime unlock. Tap the Lifetime card on the paywall, complete sandbox purchase, verify Settings → Grace Days shows the PRO chip. Screenshot attached shows full paywall with pricing, trial terms, restore button, and legal disclosures." |

### 2b. Monthly (Auto-Renewable Subscription)

App Store Connect → **Subscriptions** → create group **`FitnessStreaks Pro`** (all subs in this group share entitlement).

| Field | Value |
|---|---|
| Reference Name | `Pro Monthly` |
| Product ID | `com.jackwallner.streaks.monthly` |
| Subscription Group | FitnessStreaks Pro |
| Subscription Duration | 1 Month |
| Price | $1.99 USD/mo |
| Display Name (en-US) | `FitnessStreaks Pro · Monthly` |
| Description (en-US) | `Save every streak. At-risk alerts + automatic Grace Day saves. Billed monthly. 7-day free trial. Cancel anytime.` |
| Free Trial | Introductory Offer → New Subscribers → 7 Days → Free |
| Review Screenshot | Same paywall screenshot (see §5) |
| Review Notes | "Monthly auto-renewable subscription with 7-day free trial. Pricing is clearly displayed on paywall: '$1.99/mo — 7 days free, then $1.99/month'. Auto-renew terms and cancelation policy visible on paywall. Restore button tested and working." |

### 2c. Yearly (Auto-Renewable Subscription)

| Field | Value |
|---|---|
| Reference Name | `Pro Yearly` |
| Product ID | `com.jackwallner.streaks.yearly` |
| Subscription Group | FitnessStreaks Pro |
| Subscription Duration | 1 Year |
| Price | $14.99 USD/yr |
| Display Name (en-US) | `FitnessStreaks Pro · Yearly` |
| Description (en-US) | `FitnessStreaks Pro, billed yearly. Includes a 7-day free trial. Cancel anytime.` |
| Free Trial | Introductory Offer → New Subscribers → 7 Days → Free |
| Review Screenshot | Same paywall screenshot (see §5) |
| Review Notes | "Yearly auto-renewable subscription with 7-day free trial. Pricing clearly displayed on paywall: '$14.99/yr — 7 days free, then $14.99/year'. Best value tier shown with '$1.25/mo' monthly-equivalent breakdown. Auto-renew terms and cancelation policy visible." |

**Important** — the **Subscription Group Display Name** (`FitnessStreaks Pro`) is what users see in iOS Settings → Subscriptions. Keep it consistent with marketing.

### 2d. Localized metadata

Only en-US is required for launch. If you ship more locales later, every locale needs a Display Name + Description per product.

## 3. Submit IAPs *with* the next app version

In App Store Connect → **Distribution** → choose the new build → in the **In-App Purchases and Subscriptions** section, **add all three products to the version**. They go to review *together with* the binary. If they're not attached to a version, they sit in `Ready to Submit` forever.

## 4. App Review metadata changes

- **App Description**: add a paragraph mentioning Pro: "FitnessStreaks Pro ($29.99 lifetime, $14.99/yr, or $1.99/mo) unlocks Grace Days — automatic saves when you miss a day. Every plan includes a 7-day free trial."
- **App Privacy** → review whether StoreKit data adds anything. We don't track purchases beyond Apple's own receipt, so no changes are required, but confirm "Purchases" is unchecked (or matches reality) in the privacy nutrition labels.
- **What's New in This Version**: mention "Introducing FitnessStreaks Pro — Grace Days save your streaks automatically. 7-day free trial on all plans."
- **Promotional Text** (optional, editable post-release): "Try Pro free for 7 days. Grace Days protect your streaks automatically." Good place to highlight the free trial since this field is editable without a new binary.
- **Keywords**: add "streak tracker, habit tracker, health streaks, workout streaks, step counter streak, fitness goals, grace days"

## 5. Required Paywall Screenshot & Review Assets

Apple requires a paywall screenshot (640×920 minimum, PNG) showing the full purchase flow. Rejection triggers if any of these are missing:

### Screenshot must show:
- ✅ **All three product cards** (Monthly, Yearly, Lifetime) with prices clearly visible
- ✅ **Subscription lengths** displayed ("1 Month", "1 Year")
- ✅ **Price per period** ($1.99/mo, $14.99/yr, $29.99 once)
- ✅ **Free trial terms** prominently shown on subscription cards ("7 days free")
- ✅ **Yearly monthly-equivalent** displayed ("$1.25/mo" or similar breakdown)
- ✅ **Auto-renew disclosure** text visible on-screen (the legal block at bottom of paywall)
- ✅ **Link to Terms of Service (EULA)** — we use Apple's standard EULA
- ✅ **Link to Privacy Policy**
- ✅ **Restore Purchases button** visible and accessible
- ✅ **Cancelation policy** — "Cancel anytime" or the standard auto-renew cancellation text

### How to capture:
1. Build to iPhone simulator or device
2. Navigate to Settings → tap "Unlock Pro" or the grace-days banner
3. Screenshot the full ProPaywallView (all cards + legal block visible)
4. Resize to 640×920 minimum if needed (iPhone SE size works)
5. Upload as the Review Screenshot for each IAP product

**Verify in `ProPaywallView.swift`** — all required disclosures are present. If you change the paywall layout, re-check every item on this list before resubmitting.

## 6. Sandbox testing (before submitting)

1. App Store Connect → **Users and Access** → **Sandbox Testers** → create a new sandbox Apple ID (separate email, never used in prod).
2. On a real device: iOS Settings → **App Store** → **Sandbox Account** → sign in with that tester.
3. Build to that device, hit the paywall, verify:
   - **Lifetime** purchase succeeds → `isPro = true` immediately, paywall dismisses, Settings shows PRO chip.
   - **Monthly** purchase succeeds, free-trial copy shows ("7 days free, then $1.99/mo"), auto-renew language visible.
   - **Yearly** purchase succeeds, free-trial copy shows ("7 days free, then $14.99/yr"), monthly-equivalent displayed.
   - Force-quit + relaunch → still Pro (cached entitlement + `Transaction.currentEntitlements`).
   - Restore Purchases on a fresh install of the same Apple ID → flips back to Pro.
   - Cancel sandbox subscription via Settings → wait for next refresh → `isPro` flips to false (sandbox renewals are accelerated).
   - **Switch between tiers**: if a user bought monthly but wants yearly, purchasing yearly upgrades them correctly.

The `.storekit` config in the Xcode scheme covers most of this in the simulator without sandbox setup.

## 7. Submission gotchas (the things that always get rejected)

- **Paywall locks the app**: Don't. Free users must keep the full base experience. Only Grace Day *consumption* is gated. ✅ This is how the code works.
- **Restore button must work without a sign-in screen.** ✅ `AppStore.sync()` does this.
- **Don't use "free trial" without showing terms.** ✅ Paywall copy says "7 days free, then $X" via `introOfferDescription`.
- **All subscription terms must be visible on the paywall screen without scrolling** (or with clear indication that more info is below). Apple reviewers look for this.
- **Marketing language ("most popular", "save 80%") needs to be true.** Avoid these unless you can substantiate. If you add a "Best Value" badge to yearly, be prepared to show the math.
- **Subscription auto-renew terms must be in the paywall.** ✅ `legalBlock` text covers it.
- **Price must match across all places** — the paywall code pulls live StoreKit pricing via `product.displayPrice`, so App Store Connect pricing IS the source of truth. No hardcoded prices in the UI.

## 8. Post-launch

- Watch **Sales and Trends** → **Subscribers** for first conversions.
- Reply to any **Customer Reviews** that mention Pro within 24h.
- iOS Settings → **Subscriptions** is where users cancel — there's nothing to build here.
- Consider a **win-back offer** after 90 days for churned yearly subscribers.

## 9. Refund handling

You don't issue refunds; Apple does. If a refund happens, `Transaction.updates` fires with a revoked transaction and `refreshEntitlement()` flips `isPro` back to false automatically. Nothing to do.

## 10. Changing prices later

Use App Store Connect → IAP → Pricing. Existing yearly subscribers are grandfathered for 60 days unless they explicitly accept the new price. Monthly subscribers see the new price at next renewal. Lifetime purchasers are always grandfathered. Both behaviors are Apple's defaults — no code changes needed.

If raising prices, consider creating a new subscription tier and keeping existing subscribers on the old price to avoid mass cancelations.
