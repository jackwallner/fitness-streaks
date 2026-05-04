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

App Store Connect → **My Apps** → FitnessStreaks → **Monetization** → **In-App Purchases** (and **Subscriptions** for the yearly).

### 2a. Lifetime (Non-Consumable)

| Field | Value |
|---|---|
| Reference Name | `Pro Lifetime` |
| Product ID | `com.jackwallner.streaks.pro.lifetime` |
| Type | Non-Consumable |
| Price | $9.99 USD (Tier 10 — let App Store Connect auto-fill the rest of the price matrix) |
| Display Name (en-US) | `FitnessStreaks Pro · Lifetime` |
| Description (en-US) | `Unlock Grace Days forever. Automatically save your streaks when life gets in the way. One-time purchase.` |
| Review Screenshot | Screenshot of the paywall on iPhone (640×920 minimum, PNG) — see §5 |
| Review Notes | "Non-consumable lifetime unlock. Tap any product card on the paywall, complete sandbox purchase, verify Settings → Grace Days shows the PRO chip." |

### 2b. Yearly (Auto-Renewable Subscription)

App Store Connect → **Subscriptions** → create group **`FitnessStreaks Pro`** (any subscriber gets all subs in this group; we currently have one).

| Field | Value |
|---|---|
| Reference Name | `Pro Yearly` |
| Product ID | `com.jackwallner.streaks.pro.yearly` |
| Subscription Group | FitnessStreaks Pro |
| Subscription Duration | 1 Year |
| Price | $4.99 USD/yr |
| Display Name (en-US) | `FitnessStreaks Pro · Yearly` |
| Description (en-US) | `FitnessStreaks Pro, billed yearly. Includes a 7-day free trial.` |
| Free Trial | Introductory Offer → New Subscribers → 1 Week → Free |
| Review Screenshot | Same paywall screenshot |

**Important** — the **Subscription Group Display Name** (`FitnessStreaks Pro`) is what users see in iOS Settings → Subscriptions. Keep it consistent with marketing.

### 2c. Localized metadata

Only en-US is required for launch. If you ship more locales later, every locale needs a Display Name + Description per product.

## 3. Submit IAPs *with* the next app version

In App Store Connect → **Distribution** → choose the new build → in the **In-App Purchases and Subscriptions** section, **add both products to the version**. They go to review *together with* the binary. If they're not attached to a version, they sit in `Ready to Submit` forever.

## 4. App Review metadata changes

- **App Description**: add a paragraph mentioning Pro: e.g. "FitnessStreaks Pro ($9.99 lifetime or $4.99/yr) unlocks Grace Days — automatic saves when you miss a day."
- **App Privacy** → review whether StoreKit data adds anything. We don't track purchases beyond Apple's own receipt, so no changes are required, but confirm "Purchases" is unchecked (or matches reality) in the privacy nutrition labels.
- **What's New in This Version**: mention "Introducing FitnessStreaks Pro — Grace Days save your streaks automatically."
- **Promotional Text** (optional, editable post-release): good place to highlight the free trial.

## 5. Required Paywall Review Assets

Apple rejects subscription paywalls that don't show:

- ✅ Title of subscription
- ✅ Length of subscription
- ✅ Price per period
- ✅ Free trial terms (when applicable)
- ✅ Auto-renew disclosure
- ✅ Link to Terms of Service (EULA) — we use Apple's standard EULA
- ✅ Link to Privacy Policy
- ✅ Restore Purchases button

**Verify in `ProPaywallView.swift`** — all of these are present. If you change the paywall, re-check this list before resubmitting.

## 6. Sandbox testing (before submitting)

1. App Store Connect → **Users and Access** → **Sandbox Testers** → create a new sandbox Apple ID (separate email, never used in prod).
2. On a real device: iOS Settings → **App Store** → **Sandbox Account** → sign in with that tester.
3. Build to that device, hit the paywall, verify:
   - Lifetime purchase succeeds → `isPro = true` immediately, paywall dismisses, Settings shows PRO chip.
   - Yearly purchase succeeds, free-trial copy shows ("7 days free, then $4.99/yr").
   - Force-quit + relaunch → still Pro (cached entitlement + `Transaction.currentEntitlements`).
   - Restore Purchases on a fresh install of the same Apple ID → flips back to Pro.
   - Cancel sandbox subscription via Settings → wait for next refresh → `isPro` flips to false (sandbox renewals are accelerated).

The `.storekit` config in the Xcode scheme covers most of this in the simulator without sandbox setup.

## 7. Submission gotchas (the things that always get rejected)

- **Paywall locks the app:** Don't. Free users must keep the full base experience. Only Grace Day *consumption* is gated. ✅ This is how the code works.
- **Restore button must work without a sign-in screen.** ✅ `AppStore.sync()` does this.
- **Don't use "free trial" without showing terms.** ✅ Paywall copy says "7 days free, then $X" via `introOfferDescription`.
- **Marketing language ("most popular", "save 80%") needs to be true.** Avoid these unless you can substantiate.
- **Subscription auto-renew terms must be in the paywall.** ✅ `legalBlock` text covers it.

## 8. Post-launch

- Watch **Sales and Trends** → **Subscribers** for first conversions.
- Reply to any **Customer Reviews** that mention Pro within 24h.
- iOS Settings → **Subscriptions** is where users cancel — there's nothing to build here.

## 9. Refund handling

You don't issue refunds; Apple does. If a refund happens, `Transaction.updates` fires with a revoked transaction and `refreshEntitlement()` flips `isPro` back to false automatically. Nothing to do.

## 10. Changing prices later

Use App Store Connect → IAP → Pricing. Existing yearly subscribers are grandfathered for 60 days unless they explicitly accept the new price. Lifetime purchasers are always grandfathered. Both behaviors are Apple's defaults — no code changes needed.
