# Streak Finder audit823

Fresh max-reasoning rerun for Streak Finder, completed 2026-08-23.

## Scope and evidence standard

This audit covers only `/Users/jackwallner/fitness-streaks`. It is an audit artifact for a later implementation agent. No app source, project configuration, metadata, website, or other file was changed as part of this rerun. No commit or push was made.

Evidence labels used below:

- **Observed** means directly present in the local repository or captured in the shared ASC or RevenueCat context.
- **Inference** means a likely growth, conversion, reliability, or UX consequence of observed behavior.
- **Validate** means a live check or experiment still required before implementation.
- **Recommendation** means a concrete action for the implementation agent, not a claim that the action has already happened.

The repository is a Swift 6, XcodeGen iOS 17 and watchOS 10 project. The app target is `com.jackwallner.streaks`, the App Store ID is `6762699692`, the local project version is `1.2.8` build `147`, and the RevenueCat package is `5.72.0` (`project.yml:1-74`). The app has iPhone, Apple Watch, iOS widget, and watch widget targets sharing the App Group `group.com.jackwallner.streaks`.

The following evidence is not available with enough app-specific confidence to support numeric conclusions:

- Streak Finder-specific ASC acquisition, product-page, download, trial, conversion, rating, crash, hang, and review trend exports.
- Streak Finder-specific RevenueCat trial, subscription, entitlement, churn, MRR, and paywall funnel metrics.
- A fresh device or TestFlight run of the current build in this rerun.
- The exact ASC text behind the `review issues` link observed beside the live app listing.
- A verified list of current public ratings for App Store ID `6762699692`.

Do not use account-wide RevenueCat totals as Streak Finder totals. The previously available RevenueCat overview was account-wide, not attributable to this app.

## Executive verdict

Streak Finder has a coherent core product and a deliberately designed trial funnel. The strongest immediate download and revenue risks are consistency failures around the commercial promise, not a lack of features:

1. The live-looking landing page JSON-LD advertises `$6.99` monthly, `$29.99` yearly, and `$69.99` lifetime, while the local StoreKit configuration and local App Store description use `$1.99`, `$14.99`, and `$29.99` (`docs/index.html:33-56`, `FitnessStreaks/FitnessStreaks.storekit:4-84`, `fastlane/metadata/en-US/description.txt:29-30`). Confirm ASC and RevenueCat first, then make the site, metadata, and product copy derive from one verified price source.
2. The customer-facing name has drifted among `Streak Finder: Health Habits`, `Streak Tracker: Fitness Habits`, `Fitness Habits - Streak Finder`, and the review prompt label `Streaks`. A user should encounter one canonical brand in the App Store, website, support, purchase, and review paths.
3. The supported-metric count is not defined consistently. The App Store description and README say 9, the support and privacy pages enumerate 10 categories including heart rate, the `StreakMetric` enum has 12 cases including derived metrics, and the landing page says 12. This can create an expectation mismatch immediately after HealthKit discovery.
4. The implementation intentionally treats a RevenueCat purchase result of `.pending` as full access for onboarding and broken-streak revival. That may be appropriate as a temporary purchase UX bridge, but it is currently not separated from an active entitlement and can produce a false activation or premature revival if approval never completes (`Shared/Services/StoreKitService.swift:180-204`, `FitnessStreaks/Views/OnboardingView.swift:808-821`, `FitnessStreaks/Views/BrokenStreakSheet.swift:180-203`).
5. RevenueCat currently records custom paywall impressions only. There are no custom attributes or funnel events for onboarding discovery, trial surface, plan selection, catalog failure, purchase outcome, restore, activation, or retention. The privacy-first architecture therefore cannot explain which paths create downloads, trial starts, paid conversions, or churn.
6. Terms and privacy are the strongest documentation surfaces. Support, ASO operational notes, the paywall spec, old product vocabulary, and some scripts are stale enough to mislead Cursor, Claude, or Codex during implementation.

## Priority map

| Priority | Finding | Why it matters | First owner action |
|---|---|---|---|
| P0 if the landing page prices are live, otherwise P1 | Website price and product price conflict | A visitor can see a price that cannot be bought, which damages trust and can reduce download or trial intent | Confirm production ASC and RevenueCat prices, then replace hardcoded site offers with a verified source or remove prices from structured data |
| P1 | Brand name drift across listing, website, scripts, and review prompt | Search relevance, word-of-mouth, support recognition, and review confidence all suffer when names differ | Choose one canonical name and update or archive alternate-name instructions |
| P1 | Trial and subscription offer truth is not centralized | Local StoreKit says both monthly and yearly have 7-day trials; the paywall spec says yearly only | Pull live offer eligibility and make all surfaces render the same product truth |
| P1 | Pending purchase is granted access before entitlement activation | A pending transaction can be interpreted as a successful trial or paid activation | Add explicit pending state, delayed fulfillment, and reconciliation telemetry |
| P1 | Catalog failure silently becomes free onboarding | Product outages look like user rejection and hide a lost conversion opportunity | Record catalog load start, success, no-offer, timeout, and error separately; show a recoverable message |
| P1 | Metric count and premium vocabulary conflict | Users can feel that the app changed its promise after permission and purchase | Define the supported-metric and premium-feature glossary from code, then generate copy |
| P1 | No usage or trial funnel telemetry beyond paywall impressions | There is no evidence for which screen or cohort needs improvement | Add low-cardinality RevenueCat attributes and funnel events without raw HealthKit data |
| P1 | Broken-streak notification requests are not fully canceled | Stale notifications can appear after a recovery, goal change, or Pro downgrade | Remove pending requests matching `streaks.broken.*` and test schedule cleanup |
| P1 | Custom-streak copy says 1 while code allows 3 | A user can be told they hit a limit that is not the actual limit | Resolve the product decision and use one value in code, UI, metadata, and tests |
| P2 | Review prompt has no remote intent funnel and uses `Streaks` as its display name | The app cannot learn whether the prompt or feedback path is useful, and the label is not the current listing name | Track local intent safely, align the display name, and use ASC ratings as the authority |
| P2 | Support and operational documentation are out of date | Agents may implement retired Grace Days behavior or old release instructions | Mark current versus historical docs and add a current source-of-truth index |
| P2 | No production crash, hang, background-refresh, or catalog watchdog found | Release regressions can be discovered only after users report them or ASC data arrives | Add a read-only release monitor scaffold and MetricKit or ASC export ingestion plan |

## 1. ASC identity, release status, and metadata

### 1.1 App identity and status

**Observed, shared ASC context on 2026-08-23:**

- App Store ID: `6762699692`.
- Live listing title displayed as `Streak Finder: Health Habits`.
- Version displayed as `1.2.8`.
- Status displayed as `Ready for Distribution`.
- A visible `review issues` link was present beside the app listing. The exact issue details were not captured.

**Validate before any release or metadata upload:**

1. Open the review-issues detail and record each issue, affected version/build, resolution state, and whether it is informational or blocking.
2. Confirm the live bundle ID is `com.jackwallner.streaks`, the build is actually `147`, and the live version matches the listing metadata under review.
3. Pull the live product IDs, prices, subscription group, introductory-offer eligibility by storefront, and current entitlement mapping. The repository is not authoritative for production ASC state.
4. Pull App Analytics by app version, build, device, OS, storefront, country, acquisition source, and product page. A download or trial conclusion without those dimensions will be misleading.

### 1.2 Local configuration and product truth

`project.yml:10-21` declares RevenueCat `5.72.0`, version `1.2.8`, and build `147`. The iOS target has the `REVENUECAT` compilation condition and links the RevenueCat package (`project.yml:45-74`). The local StoreKit configuration contains:

| Product | Local product ID | Local type | Local price | Local intro offer |
|---|---|---|---:|---|
| Lifetime | `com.jackwallner.streaks.lifetime` | Non-consumable | `$29.99` | None |
| Monthly | `com.jackwallner.streaks.monthly` | P1M subscription | `$1.99` | 7 free days |
| Yearly | `com.jackwallner.streaks.yearly` | P1Y subscription | `$14.99` | 7 free days |

Evidence: `FitnessStreaks/FitnessStreaks.storekit:4-84`.

This file is a development StoreKit configuration, not proof of live ASC or RevenueCat pricing. It is still the source used for local testing, so it must not contradict the code or test assumptions.

The local test configuration says both monthly and yearly have a 7-day free trial (`FitnessStreaks/FitnessStreaks.storekit:34-70`). The current paywall spec says `Yearly only - 7 days` (`my-current-paywall-spec.md:198-206`). The current App Store description says both monthly and yearly have a 7-day free trial (`fastlane/metadata/en-US/description.txt:29-30`). This is a P1 offer-definition conflict. Confirm whether monthly trials are intentionally live, then update the spec and tests.

### 1.3 Metadata completeness and limits

**Observed in local Fastlane metadata:**

- 50 real locale directories exist. `review_information` is a separate non-locale directory.
- Every real locale has `name.txt`, `subtitle.txt`, `keywords.txt`, `description.txt`, `promotional_text.txt`, `support_url.txt`, `marketing_url.txt`, and `privacy_url.txt`.
- en-US values, excluding the trailing newline, are 28 characters for name, 30 for subtitle, 96 for keywords, and 147 for promotional text. These are within the usual ASC field limits.
- en-US current values are:
  - Name: `Streak Finder: Health Habits`
  - Subtitle: `Find Streaks You Already Built`
  - Keywords: `stand,ring,step,sleep,move,healthkit,hidden,uncover,nudge,logging,momentum,chain,mindful,heatmap`
  - Promotional text: `Your Apple Health history may already contain a streak worth protecting. Find it automatically, keep it visible, and start 7 days of Streaks+ free.`
  - Marketing URL: `https://jackwallner.github.io/fitness-streaks/`
  - Support URL: `https://jackwallner.github.io/fitness-streaks/support.html`
  - Privacy URL: `https://jackwallner.github.io/fitness-streaks/privacy-policy.html`
- A simple currency and decimal scan matched 44 of 50 localized descriptions. The en-US description contains `$1.99`, `$14.99`, and `$29.99` (`fastlane/metadata/en-US/description.txt:29-30`).

**Recommendation:** remove hardcoded prices from App Store descriptions and promotional copy unless there is a deliberate, automated process that updates every locale after a verified price change. Storefront prices, introductory offers, and purchasing disclosures should render from Apple product data in the app. App Store metadata should sell the value and state that the current price and offer are shown before purchase. PPP pricing makes static USD figures especially likely to become stale.

**Metadata growth opportunities:**

1. Preserve the current name and subtitle while establishing a baseline. The current title owns the distinctive `Streak Finder` phrase and communicates the Health focus. Do not rename based on old Astro notes without current App Analytics and search-rank evidence.
2. Use ASC acquisition sources and product-page conversion to decide whether the listing needs a name, subtitle, screenshot, or keyword test. A keyword change without a rank and conversion baseline cannot be judged.
3. Test one positioning hypothesis at a time:
   - Hidden momentum: `Find streaks you already built`.
   - Apple Health discovery: automatic, read-only discovery from existing data.
   - Protection: reminders, heatmaps, and recovery features.
   - Multi-surface utility: iPhone, widgets, and Apple Watch.
4. Keep claims observational and product-specific. Do not make treatment, diagnosis, disease prevention, or medical outcome claims. `Streak Finder` can say it finds, displays, and helps users keep an activity streak. It should not promise that a streak will improve health.
5. Review all 50 localizations with native speakers or a qualified localization reviewer. The presence of a complete file set does not prove translation quality, search intent, or cultural fit. Pay special attention to terms that remain in English, Apple Watch, HealthKit, fitness, sleep, and any health-related wording.
6. Build a metadata linter that checks field limits, required files, price tokens, supported product names, URL parity, product ID references, and canonical brand terms before upload.

### 1.4 Name and brand drift

The current ASC and website name is `Streak Finder: Health Habits` (`docs/index.html:11,16,21,23,30`). Other local sources use competing names:

| Source | Conflicting value | Evidence |
|---|---|---|
| Current ASC and website | `Streak Finder: Health Habits` | `fastlane/metadata/en-US/name.txt`, `docs/index.html:11,30` |
| Astro setup guide | `Fitness Habits - Streak Finder` | `docs/astro-aso-setup.md:5-12` |
| ASO script | `Streak Tracker: Fitness Habits` | `scripts/apply-streak-tracker-name.py`, `scripts/aso-fitness-locale-readout.py` |
| Astro keyword data | `Fitness Habits - Streak Finder` | `scripts/astro-keywords-us.json` |
| Review prompt | `Streaks` | `Shared/Utilities/AppStoreReviewLinks.swift:4-10` |
| Product display names | `FitnessStreaks Pro` | `FitnessStreaks/FitnessStreaks.storekit:12,31,49,75` |

**Inference:** a user who came from the website, bought through the paywall, and later sees a review prompt can reasonably wonder whether these are the same app. Search and support agents can also follow the wrong rename script.

**Recommendation:** choose one customer-facing name, likely the current ASC name unless current marketing evidence supports a tested change. Store it in one non-generated source-of-truth file. Make metadata generation, site JSON-LD, in-app review labels, support copy, product display names, and ASO scripts consume or validate it. Archive or clearly mark alternate-name experiments as historical.

## 2. Download and landing-page audit

### 2.1 Price and offer mismatch

`docs/index.html:33-56` declares these structured-data offers:

- Free: `$0`.
- Monthly: `$6.99`.
- Yearly: `$29.99`.
- Lifetime: `$69.99`.

The local StoreKit values are `$1.99`, `$14.99`, and `$29.99`. The difference is material. It is not safe to assume the website values are old or that the local values are current. The implementation agent must pull production ASC and RevenueCat values and label the result as confirmed.

**Acceptance criteria:**

- Visible website pricing, JSON-LD offers, App Store description, paywall, terms, and product names agree on product type and offer semantics.
- If prices are storefront-dependent, the landing page either avoids exact prices or clearly explains that Apple shows the current local price.
- The site does not advertise a trial on a product that is not eligible for that user or storefront.
- A changed ASC price creates a linter failure before site or metadata release.

### 2.2 Landing-page technical consistency

Observed issues in `docs/index.html`:

- The canonical URL is `https://jackwallner.com/ios/fitness-streaks/` (`docs/index.html:13`), while App Store metadata and the app's Settings links use GitHub Pages URLs. This may be intentional, but it creates two public URL families.
- The App Store download URL uses the old slug `streak-counter-steps-rings` even though the numeric ID is correct (`docs/index.html:66`). Use the stable numeric URL or verify that the old slug redirects correctly in every target storefront.
- JSON-LD says the free tier discovers 12 Apple Health metrics (`docs/index.html:38`), while README and App Store descriptions say 9 and support/privacy enumerate 10 named categories.
- JSON-LD contains an aggregate rating of 5 with count 1 (`docs/index.html:59-62`). No current ASC or public rating evidence was available in this audit to verify it. Remove or update it only from an authoritative, current public source.
- The description and offers use `Grace Days` (`docs/index.html:12,44,50,56`), while the current paywall and settings language emphasize auto-save and planned freezes. The local StoreKit file also contains old Grace Day product descriptions.
- Screenshot and social assets are served from GitHub Pages while the canonical page is on `jackwallner.com`. Confirm that image URLs are stable, indexable, and not blocked by a deployment change.

**Download conversion recommendations:**

1. Set one canonical landing host and use redirect-safe links from ASC, app, social, and support.
2. Add source parameters to the landing URL and preserve them through the App Store click where possible. Compare page-to-store clicks with ASC acquisition sources.
3. Keep the hero promise concrete: the app reads existing Apple Health history and reveals activity streaks without manual logging. Show the first useful screen, not only a generic fitness image.
4. Show the same iPhone, Apple Watch, widget, and privacy benefits that the app can actually deliver in the current build.
5. Do not use a static rating badge until its value is current and attributable to App Store ID `6762699692`.
6. Test landing-page variants against click-through to the store, not only page engagement. Guardrail the rate of refund, uninstall, and trial cancellation after acquisition source.

## 3. Trial-start and purchase-flow audit

### 3.1 Current flow map

The primary funnel is:

```text
Fresh launch
  -> user-initiated HealthKit authorization
  -> up to 400 days of local discovery
  -> intensity selection
  -> core streaks preselected
  -> selection over free cap when candidates exist
  -> full-screen trial page
  -> annual-first direct trial purchase
  -> entitlement refresh
  -> dashboard
```

There are additional paywall entry points:

```text
Dashboard after setup, delayed trial offer
Settings subscription surface
Tracked-streak cap in picker
Locked history heatmap in detail
Broken streak recovery
Onboarding full paywall fallback
```

Relevant evidence:

- HealthKit authorization is user initiated in `OnboardingView.beginDiscoveryWithAuth` (`FitnessStreaks/Views/OnboardingView.swift:746-756`).
- Discovery preselects five core metrics, intentionally above the free tracked limit of three (`FitnessStreaks/Views/OnboardingView.swift:767-786`).
- The selection count is recorded before trimming so the post-onboarding offer can say how many streaks would be kept (`FitnessStreaks/Views/OnboardingView.swift:789-805`).
- Onboarding loads offerings if necessary and routes to a trial page when an eligible trial package exists (`FitnessStreaks/Views/OnboardingView.swift:843-881`).
- A catalog failure trims to the free cap and completes setup instead of blocking first launch (`FitnessStreaks/Views/OnboardingView.swift:854-860`).
- The annual package is preferred for direct trial selection (`FitnessStreaks/Views/OnboardingView.swift:911-920`, `FitnessStreaks/Views/TrialOfferSheet.swift:170-177`).
- The post-onboarding `TrialOfferSheet` is delayed and guarded by `hasSeenTrialOffer` in `FitnessStreaks/App.swift` and `FitnessStreaks/Views/TrialOfferSheet.swift`.
- `PaywallView` tracks an impression, loads products, defaults to yearly, displays monthly and lifetime alternatives, and dismisses on `grantsUnlimitedTrackedStreaks` (`FitnessStreaks/Views/PaywallView.swift:35-124`).

### 3.2 What is strong

- Permission is requested after a user action, not immediately on launch.
- The app gives HealthKit discovery a meaningful job before asking for payment.
- A user can leave the offer and still complete onboarding with a free cap, so a catalog problem does not brick first launch.
- The paywall displays live localized prices from RevenueCat products rather than hardcoded currency strings (`FitnessStreaks/Views/PaywallView.swift:260-375`).
- Annual, monthly, lifetime, terms, privacy, and restore surfaces are all represented on the full paywall.
- A delayed post-onboarding offer avoids stacking the trial sheet on top of onboarding and records `hasSeenTrialOffer` to avoid double presentation.
- Broken-streak recovery is contextual and only offers revival for a recent break (`FitnessStreaks/Views/BrokenStreakSheet.swift:214-222`).

### 3.3 Trial conversion risks and recommendations

#### A. The over-cap onboarding is effective but can feel coercive

**Observed:** five core metrics are preselected and a free user is intentionally taken over the three-streak cap (`FitnessStreaks/Views/OnboardingView.swift:772-776`). Dismissing the offer trims the selection to the first three entries in `manualStreakOrder` (`FitnessStreaks/Views/OnboardingView.swift:824-835`).

**Inference:** the user may interpret the post-purchase loss of two visible streaks as a bait-and-switch if the cap is not explained before the selection is made.

**Recommendation:** test an explicit, neutral explanation beside the selection count: `Free tracks 3. Streaks+ keeps all 5 discovered streaks.` Show which rows will remain after a decline, preserve user-selected order, and offer a clear free continuation. Do not hide the free path or imply that a health outcome depends on paying.

#### B. A catalog outage is classified as a free choice

**Observed:** when offerings cannot be loaded, onboarding trims and completes setup (`FitnessStreaks/Views/OnboardingView.swift:854-860,874-881`). There is no remote funnel event for that branch.

**Inference:** product outages reduce trial starts while analytics make the result look like users intentionally declined. This is both a conversion blind spot and a release watchdog gap.

**Recommendation:** distinguish these states:

- `catalog_loading`
- `catalog_loaded_with_trial`
- `catalog_loaded_without_trial`
- `catalog_timeout`
- `catalog_error`
- `catalog_user_dismissed`

For a recoverable error, preserve the user's selection, show `Prices are temporarily unavailable`, offer retry, and still offer a clearly labeled free continuation. If the product decision is to never delay onboarding, log the branch and surface a later trial offer.

#### C. The direct trial path hides plan choice

**Observed:** the direct trial CTA prefers yearly even when multiple products may be eligible. The full paywall is reachable through `See all plans` or fallback.

**Inference:** annual-first may maximize yearly conversion, but it can reduce trial starts among users who prefer monthly or lifetime. The effect cannot be known without a plan-selection event.

**Recommendation:** run an experiment comparing annual-first direct CTA with a plan-choice trial page. Keep the offer disclosure explicit: trial duration, product after trial, price, billing period, and cancellation timing. Primary metrics should include trial start, not only paid revenue.

#### D. Pending purchase is not a stable activation state

**Observed:** `StoreKitService.purchase` returns `.pending` when the customer info does not yet contain an active entitlement, but sets `purchaseGrantsFullStreakAccess = true` for both `.purchased` and `.pending` (`Shared/Services/StoreKitService.swift:180-204`). Onboarding treats that grant as sufficient to restore all selected streaks and complete setup (`FitnessStreaks/Views/OnboardingView.swift:808-821,895-909`). Broken-streak revival does the same (`FitnessStreaks/Views/BrokenStreakSheet.swift:180-203`). The paywall comments explicitly describe the temporary access bridge (`FitnessStreaks/Views/PaywallView.swift:101-105`).

**Inference:** a pending parental approval, interrupted payment, or delayed transaction can create a temporary paid state, revive a streak before entitlement confirmation, and inflate the apparent activation funnel. The later delegate refresh can remove access, which can feel like a regression.

**Recommendation:** separate the states:

- `purchase_submitted`
- `purchase_pending_approval`
- `purchase_confirmed_by_customer_info`
- `entitlement_active`
- `purchase_failed`
- `purchase_cancelled`

For pending, show a non-blocking status and preserve the intended selection locally, but do not permanently mark the product as active or consume a one-time revival until the entitlement is active. If an immediate access bridge is required for UX, make it time-bounded, reconcile it on every refresh, and never call the event `purchase_completed` until RevenueCat confirms it.

#### E. Restore feedback is inconsistent

The full paywall has an explicit restore status path (`FitnessStreaks/Views/PaywallView.swift:571-579`). The onboarding footer and smaller trial surfaces also expose restore actions, but their success, no-purchase, and error states should be checked on every route. A restore action should either dismiss after confirmed active entitlement or explain exactly what happened. It should not leave a user with a silent tap or an apparently unchanged selection.

#### F. Empty-data users need a value-preserving trial decision

The empty discovery path can still route through the trial or paywall logic. Validate whether a user with no HealthKit samples or denied access sees a paid offer before seeing a useful explanation. The user should be able to finish setup, understand how to add activity data, and return to the offer after the app has demonstrated value. Do not imply that the app can diagnose why data is absent.

### 3.4 Trial metrics to establish

Pull these by app version, build, storefront, acquisition source, and paywall surface:

1. First launch to HealthKit authorization prompt.
2. Authorization accepted, denied, partial, or unavailable.
3. Discovery completed, discovery error, candidate count bucket.
4. Selection count bucket and free-cap exposure.
5. Trial surface impression, direct CTA tap, plan-choice tap, dismiss, and restore.
6. Trial eligibility by product and storefront.
7. Trial start, trial conversion, trial cancellation, refund, and entitlement activation latency.
8. Paywall impression to product selection to purchase start to outcome.
9. Seven-day active use, first goal completion, first broken streak, and D7 or D30 retention.
10. Catalog failure rate and purchase pending rate during each release window.

## 4. RevenueCat and purchase instrumentation

### 4.1 Current implementation

**Observed:** RevenueCat is configured from the bundled `RevenueCat.plist` on device. The public app key is present in the plist, but its value is intentionally not repeated here (`FitnessStreaks/RevenueCat.plist:5-7`). Simulator purchase and impression paths return without configuring production purchases, which is correct for local testing (`Shared/Services/StoreKitService.swift:130-164,180-218`).

The repository contains one RevenueCat analytics integration:

```swift
Purchases.shared.trackCustomPaywallImpression(
    CustomPaywallImpressionParams(paywallId: id)
)
```

Evidence: `Shared/Services/StoreKitService.swift:148-163`.

No `setAttributes`, `identify`, `logIn`, `logOut`, or equivalent custom customer-attribute calls were found. No Streak Finder-specific RevenueCat metric export was available in context.

Existing paywall impression IDs found in the app include:

- `streaks_onboarding_sheet`
- `streaks_trial_sheet`
- `streaks_dashboard_sheet`
- `streaks_settings_sheet`
- `streaks_picker_sheet`
- `streaks_picker_cap_sheet`
- `streaks_broken_sheet`
- `streaks_detail_sheet`

Keep these IDs stable. If a layout or copy test changes the experience, add a variant suffix or a separate experiment key rather than silently reusing a control ID.

### 4.2 Entitlement handling

`isEntitled` currently returns true when any active RevenueCat entitlement exists (`Shared/Services/StoreKitService.swift:292-304`). The comment says there is one project entitlement and that its dashboard name is `Fitness Habits - Streak Finder Pro`, not `pro`.

**Strength:** this avoids a brittle mismatch between a display name and an assumed entitlement identifier.

**Risk:** if another entitlement is added to the RevenueCat project later, any active entitlement would grant the whole Pro feature set.

**Recommendation:** use a named, allowlisted entitlement identifier once the production project is confirmed, or validate that the project has exactly one entitlement at startup and log a loud configuration error if that changes. Add tests for no entitlement, the expected entitlement, an unexpected entitlement, expired entitlement, billing issue, restore, and downgrade.

### 4.3 Recommended custom attributes

RevenueCat customer attributes are state, not event history. Use a small namespaced set of low-cardinality values, overwrite them at meaningful transitions, and use local structured logs or an approved event pipeline for repeated events. Do not send raw HealthKit samples, raw streak history, precise activity values, precise sleep values, workout names, email, or other identifying data.

| Attribute | Example values | Set or refresh at | Purpose |
|---|---|---|---|
| `sf_app_version_build` | `1.2.8-147` | RevenueCat configure and app active | Segment release regressions |
| `sf_storefront` | Apple storefront code | Configure or first product load | Explain price and offer differences |
| `sf_onboarding_state` | `started`, `discovery_done`, `selected`, `completed` | Onboarding transitions | Locate activation loss |
| `sf_candidate_count_bucket` | `0`, `1-2`, `3-5`, `6+` | `handleLoadFinished` | Compare value discovery |
| `sf_selected_count_bucket` | `0`, `1-3`, `4-5`, `6+` | Before trial routing | Quantify cap pressure |
| `sf_free_cap` | `3` | Onboarding and picker | Keep analysis interpretable after product changes |
| `sf_trial_surface` | `onboarding`, `post_onboarding`, `broken_streak`, `none` | Surface presentation | Compare trial entry points |
| `sf_trial_eligible_products` | `annual`, `monthly`, `none`, `unknown` | Eligibility refresh | Explain direct-offer availability |
| `sf_paywall_surface` | Stable impression ID | Paywall impression | Join paywall state to purchase outcome |
| `sf_selected_plan` | `annual`, `monthly`, `lifetime` | Product card selection | Measure plan preference |
| `sf_catalog_state` | `loading`, `success`, `timeout`, `error`, `no_trial` | Product load completion | Detect monetization outages |
| `sf_last_purchase_state` | `started`, `cancelled`, `pending`, `confirmed`, `failed`, `restored` | Purchase or restore outcome | Separate intent from activation |
| `sf_entitlement_state` | `free`, `active`, `billing_issue`, `unknown` | Customer info refresh | Reconcile access |
| `sf_streak_age_bucket` | `0-2`, `3-6`, `7-29`, `30+` days | Before contextual offer | Personalize without raw history |
| `sf_active_streak_count_bucket` | `0`, `1-3`, `4-6`, `7+` | Dashboard refresh | Compare perceived value |
| `sf_notification_state` | `off`, `authorized`, `denied`, `pro_locked` | Settings change or app active | Explain reminder adoption |
| `sf_watch_state` | `unknown`, `not_detected`, `paired_or_used` | Optional, if a privacy-approved signal exists | Compare cross-device value |

`sf_watch_state` should only be added if the implementation can derive it without collecting more data than the user expects. If there is no reliable signal, omit it.

### 4.4 Recommended events and insertion points

If the chosen RevenueCat SDK or backend does not support the exact event API, record these as privacy-safe structured local logs and export only through an approved system. Do not invent a RevenueCat event API without checking SDK `5.72.0` documentation.

| Event | Insertion point | Required properties |
|---|---|---|
| `sf_onboarding_started` | Root onboarding presentation | app version, first launch versus returning |
| `sf_health_authorization_result` | After `requestAuth` | granted, denied, unavailable, partial if observable |
| `sf_discovery_completed` | `OnboardingView.handleLoadFinished` | candidate bucket, data window, duration bucket, error state |
| `sf_selection_submitted` | `finishWithSelection` | selected bucket, free cap, intensity, candidate bucket |
| `sf_trial_surface_impression` | Onboarding trial, post-onboarding sheet, broken-streak sheet | surface, eligibility, selected bucket |
| `sf_trial_cta_tapped` | Direct trial CTA | surface, product, price locale, trial days |
| `sf_paywall_impression` | Existing impression method | stable surface ID, context type |
| `sf_plan_selected` | Yearly, monthly, lifetime card tap | surface, product |
| `sf_purchase_started` | Before `Purchases.shared.purchase` | product, surface, trial eligible |
| `sf_purchase_result` | After purchase returns | purchased, pending, cancelled, failed, error category |
| `sf_entitlement_changed` | RevenueCat delegate and refresh | free, active, billing issue, source |
| `sf_restore_result` | After restore | active, none, error category |
| `sf_catalog_result` | After offerings load | success, timeout, no trial, error category |
| `sf_trial_offer_dismissed` | Not now or full paywall close | surface, selected product if any |
| `sf_broken_streak_recovery` | Revival success or failure | age bucket, offer surface, entitlement state |
| `sf_review_prompt_intent` | Review sheet and native request path | enjoyment, store-link intent, feedback intent, native request invoked |

Do not use raw HealthKit values as event properties. Coarse buckets are enough to answer whether a 45-day or 300-day streak context changes conversion without uploading the history itself.

## 5. How the app is used, value moments, and revenue opportunities

### 5.1 What can be inferred from source

The product is a local discovery and reinforcement loop:

- `HealthKitService.fetchHistory(days:)` reads roughly 400 days of daily data and 90 days of hourly steps (`Shared/Services/HealthKitService.swift:163-206,209-247`).
- `StreakEngine.discover` evaluates thresholds across daily and weekly cadences. The project guide says a streak needs three days or two weeks, and the current unit stays live until it ends (`CLAUDE.md:40-49`).
- The dashboard uses one hero streak plus badges, and users can inspect a calendar heatmap and detail view.
- The app writes a local App Group snapshot for widgets and watch complications. Widgets do not query HealthKit directly (`CLAUDE.md:26-38`).
- Pro value is expressed through auto-save, at-risk alerts, history heatmaps, custom tracking, planned freezes, and expanded tracking, depending on current source and surface.

These are product hypotheses, not usage measurements. The repository cannot tell us which metrics users discover, which streaks they keep, whether users add widgets, or which paywall surface produces revenue.

### 5.2 Activation definition to adopt

Use a staged activation model so a download is not mistaken for value:

1. `opened_app`.
2. `health_authorization_completed` or an explained no-data path.
3. `discovery_completed` with at least one candidate or a clear empty state.
4. `first_streak_selected`.
5. `dashboard_seen_with_snapshot`.
6. `first_goal_completed`.
7. `first_return_visit`.
8. `widget_or_watch_surface_used`, if that signal is collected.
9. `trial_started`.
10. `entitlement_active`.

The first primary activation metric should be `discovery_completed -> dashboard_seen`, not trial start alone. A trial that starts before the user understands the product can convert poorly and generate refunds.

### 5.3 Revenue opportunities that fit the existing product

Prioritize opportunities that make an existing observed value more visible:

- Let a user see the first three discovered streaks immediately, then clearly label the additional discovered streaks as locked. This is a testable alternative to silently trimming after a decline.
- Make the first paywall context-specific: `Keep all 5 streaks you already built`, `See your full history`, or `Revive yesterday's break`. The context should be truthful and derived from the current screen.
- Show live localized price and trial terms next to the selected plan. The existing paywall already does this; validate readability at accessibility sizes.
- Keep lifetime available as a clear one-time alternative. Test whether showing lifetime as a secondary row increases total revenue or cannibalizes annual conversion.
- After a catalog failure, offer a later retry on the dashboard instead of treating the user as permanently free.
- Treat widgets and Apple Watch as retention surfaces. Measure whether users who add them return more often before changing the paywall.
- Keep the app's privacy and read-only story as a conversion asset. Do not add analytics that upload HealthKit values merely to improve targeting.

## 6. Native paywall and UX audit

### 6.1 Paywall structure

`PaywallView` intentionally uses a single viewport with a hero, feature rows, product cards, trust/legal copy, and a pinned purchase block (`FitnessStreaks/Views/PaywallView.swift:114-124`). It defaults to yearly (`FitnessStreaks/Views/PaywallView.swift:50`) and displays live prices, calculated monthly equivalent, savings, trial chips, restore, terms, privacy, and purchase status.

This is a reasonable baseline, but the single-viewport claim is a risk. Dynamic Type, translated strings, small iPhone heights, large text, VoiceOver focus order, and a context banner can cause clipping or make the legal disclosure hard to read.

**Required validation:**

- iPhone SE-class height, standard iPhone, large iPhone, and every supported orientation.
- Dynamic Type from default through the largest accessibility sizes.
- VoiceOver: product card names must include product type, billed price, trial status, and recurring or one-time behavior. The selected state must be announced.
- Reduce Motion and Increase Contrast.
- Light and dark appearances.
- Slow catalog load, no catalog, network interruption, product unavailable, purchase pending, purchase failure, restore with entitlement, and restore with no purchase.
- Trial-eligible and trial-ineligible customers.
- All three product selections, including lifetime, not only annual.

### 6.2 Native paywall surfaces and testable nooks

The existing surface IDs provide a good experiment boundary:

| Surface | Current trigger | Current opportunity |
|---|---|---|
| `streaks_onboarding_sheet` | Onboarding fallback or selection completion | Explain free cap and preserve user choice |
| `streaks_trial_sheet` | Post-onboarding delayed offer | Compare direct annual CTA with plan choice |
| `streaks_dashboard_sheet` | Dashboard at-risk or plan entry | Use current streak context and avoid interrupting first value |
| `streaks_settings_sheet` | Settings subscription row | Explain what is unlocked without urgency language |
| `streaks_picker_sheet` | Tracked-streak picker | Show locked discovered rows and keep selection state |
| `streaks_picker_cap_sheet` | Selecting over free cap | Make the exact cap and retained rows explicit |
| `streaks_broken_sheet` | Recent broken streak | Test recovery copy and a clear free alternative |
| `streaks_detail_sheet` | Locked history heatmap | Show a meaningful preview without making it unreadable or deceptive |

Check dismiss behavior at every caller. Some paywall presentations disable interactive dismissal, while others expose a close button or rely on the default sheet behavior. The user should never be trapped by a purchase surface, and a close should preserve data and selection state.

### 6.3 Free and Pro terminology

The custom-streak implementation has a direct contradiction:

- `StreakPickerSheet.freeCustomLimit = 3` and `canBuildCustom` allow three free custom streaks (`FitnessStreaks/Views/Components/StreakPicker.swift:166-188`).
- The explanatory UI says `Free includes 1 custom streak` (`FitnessStreaks/Views/Components/StreakPicker.swift:275-280`).

This is a P1 copy and product-rule issue. Decide whether the intended free limit is 1 or 3, then update the static constant, onboarding, settings, paywall feature rows, test fixtures, metadata, support, and terms if needed. A user should not hit a paywall earlier or later than the copy promises.

Other vocabulary drift:

- Current `PaywallView` uses auto-save, freeze days, and at-risk alerts (`FitnessStreaks/Views/PaywallView.swift:126-239`).
- Current Settings contains planned freeze controls (`FitnessStreaks/Views/SettingsView.swift:690-752`).
- The old paywall spec and local StoreKit descriptions use Grace Days (`my-current-paywall-spec.md:48-107`, `FitnessStreaks/FitnessStreaks.storekit:11,74`).
- `StreakSettings` retains legacy `earnedGraceDays` and `graceAwardTier` keys. This may be intentional migration compatibility, but it should not be presented as current product behavior.

Use a glossary with explicit status: current, compatibility-only, experiment, or archived.

### 6.4 Health and wellness compliance

The terms page correctly says the app is a personal fitness tracking and visualization tool, depends on available HealthKit data, and does not diagnose, prevent, treat, or cure any condition (`docs/terms.html:96-113`). Preserve this language.

Copy that deserves a compliance review before marketing expansion:

- `DiscoveryIntensity.lifeChanging` says `Building the daily habit changes everything` (`Shared/Services/StreakSettings.swift:21-26`). It is not a diagnosis claim, but it implies a broad outcome. Prefer language about challenge level and consistency rather than health transformation.
- Settings promotes external `1-on-1 virtual personal training and nutrition coaching` with links to `e3fit.me` (`FitnessStreaks/Views/SettingsView.swift:820-865`). Confirm the relationship, disclosure, destination content, and App Review treatment. Keep this clearly separate from Streak Finder's read-only visualization service and avoid treatment or diagnosis claims.
- Heart-rate minutes are computed as an activity heuristic above 100 BPM (`Shared/Services/HealthKitService.swift:163-183` and the heart-rate implementation). Do not market this as a medical or fitness assessment. Validate the label and disclaimer for any screen that exposes it.

## 7. Ratings and review funnel

### 7.1 Current flow

`ReviewPromptTracker` uses App Group storage and production gates of at least five launches, seven days since first open, three positive moments, one prompt per session, and a 120-day cooldown after `Not now` (`Shared/Services/ReviewPromptTracker.swift:24-33,61-95`). Positive moments are recorded for hero growth or a newly met goal. The app suppresses the passive prompt during competing trial, paywall, or tutorial states in the surrounding coordinator.

`ReviewPromptSheet` offers three paths:

- positive user: open the App Store write-review URL;
- not really: send feedback by email;
- maybe later: request Apple's native review surface on dismissal.

The write-review URL uses the storefront country and stable numeric ID (`Shared/Utilities/AppStoreReviewLinks.swift:12-46`). The native prompt remains Apple-controlled, so `requestReview` is an intent, not a guaranteed display or rating.

### 7.2 Review risks and opportunities

1. `AppStoreReviewLinks.displayName` is `Streaks`, while the listing and website are `Streak Finder: Health Habits` (`Shared/Utilities/AppStoreReviewLinks.swift:4-10`). Align the label so the review prompt feels native to the current app.
2. The app records local eligibility and terminal outcomes, but there is no remote count of prompt shown, positive response, store-link intent, feedback intent, native request invocation, or later rating. Add privacy-safe funnel counts or use ASC ratings as the only outcome authority.
3. A direct write-review link can be useful, but it may bypass the native prompt's Apple-controlled flow. Test its open rate, return-to-app behavior, and support feedback. Do not claim that a user submitted a rating merely because the link opened.
4. The current positive-moment definition is narrow. Test an at-risk recovery, first widget use, first completed selected streak, or first successful heatmap visit only if it is demonstrably positive and does not interrupt the user.
5. Keep feedback capture available and do not route dissatisfied users toward a public rating request. The current split is directionally correct.
6. Verify the website's JSON-LD rating value and count against a current public App Store page. Until verified, treat `ratingValue: 5` and `ratingCount: 1` as untrusted stale metadata, not as a growth asset.

### 7.3 Rating experiment guardrails

Primary metrics:

- review prompt impression;
- positive, negative, and later responses;
- store-link open intent;
- feedback compose intent;
- native review request intent;
- current ASC rating volume and average, pulled separately.

Guardrails:

- no increase in prompt dismissal during onboarding or purchase;
- no increase in support complaints about interruption;
- no reduction in D7 retention;
- no health or medical outcome claim in the prompt.

## 8. Website, support, terms, privacy, and data-consistency audit

### 8.1 Good alignment

- Privacy says HealthKit is read-only, processed on-device, and not sent to a server (`docs/privacy-policy.html:86-117`).
- Terms accurately describe dependence on Health permissions, available samples, device software, and background refresh (`docs/terms.html:96-113`).
- Terms provide Apple billing, auto-renewal, cancellation, refund, and restore guidance.
- Source code uses local App Group and HealthKit read paths. The main product and legal copy avoid treatment and diagnosis claims.

Per the requested scope, the RevenueCat disclosure is not treated as a defect merely because public product copy emphasizes local HealthKit processing or no analytics. RevenueCat purchase and entitlement processing is already disclosed in the privacy page (`docs/privacy-policy.html:109-123`). This audit does not expand that issue into a separate “no tracking” inconsistency report.

### 8.2 Findings

| Surface | Observed evidence | Risk | Recommendation |
|---|---|---|---|
| Landing page | Prices, 12 metrics, Grace Days, old App Store slug, rating JSON-LD (`docs/index.html:33-68`) | Acquisition and trust mismatch | Generate or lint from current product truth |
| Support | Last updated May 2, 2026; describes permissions, widgets, and notifications but not current trial, restore, Streaks+, picker cap, or planned freeze (`docs/support.html:52-92`) | A new user cannot recover from a purchase or onboarding issue using the support page | Update after product truth is fixed and link subscription management and restore help |
| Privacy | Last updated August 17, 2026; current HealthKit and purchase description | Good baseline, but metric list should use the same supported-metric definition as App Store copy | Reconcile list after defining the metric contract |
| Terms | Last updated August 17, 2026; current subscription and health disclaimer | Good baseline | Keep prices dynamic and preserve the disclaimer |
| App Store description source | 9 metrics, explicit prices, “zero tracking” copy (`docs/app-store-description.txt:1-33`) | Parallel source can diverge from Fastlane metadata | Mark as generated or archive it |
| Settings links | Privacy uses GitHub Pages URL; coach links point to `e3fit.me` (`FitnessStreaks/Views/SettingsView.swift:943-985`, `820-865`) | URL family and third-party destination need ownership and uptime checks | Choose canonical host and verify external disclosure |

### 8.3 Canonical content contract

Create a single current content contract for the implementation agent with:

- canonical app name and short description;
- supported metric definition and count, including whether derived metrics count;
- current free cap and custom-streak cap;
- current premium feature names, including whether the product is auto-save, freeze, Grace Day, or a different mechanism;
- product IDs, subscription periods, trial eligibility semantics, and price policy;
- App Store ID, bundle IDs, support URL, privacy URL, terms URL, and canonical landing URL;
- health and wellness wording constraints;
- current version and build only where a document genuinely needs it.

Everything else should be generated, validated, or explicitly archived.

## 9. Crash, regression, and watchdog signals

### 9.1 Current evidence

The repository uses `os.Logger` in app services, including HealthKit, StreakStore, Notifications, and app lifecycle paths. A source search did not find a production Crashlytics, Sentry, MetricKit subscriber, remote exception pipeline, or release watchdog. No Streak Finder-specific ASC crash or hang export was available.

The dated `ios27StreakFinder.md` audit reports a Debug build, unit tests, rebuild, install, launch, and UI snapshot pass on 2026-08-05. It also records follow-up issues:

- redundant `NSDecimalNumber` casts in `Shared/Services/StoreKitService.swift:248,261`;
- an unreachable default switch branch in `FitnessStreaks/Views/Components/StreakPicker.swift:684`;
- main-actor isolation warnings in `FitnessStreaksTests/PaidFeatureTests.swift`;
- unused values in `CustomStreakEdgeCaseTests.swift`.

That report is useful historical evidence, not a current green build claim.

### 9.2 Release-window watchdog specification

A read-only watchdog should run after each TestFlight or App Store release and daily for the first seven days. It should ingest ASC exports or API responses, App Store Connect Diagnostics, and RevenueCat exports only where the privacy and account permissions permit. It should not send notifications in the initial scaffold.

Minimum signals:

| Signal | Dimensions | Suggested alert condition | Why |
|---|---|---|---|
| Crash-free users and sessions | build, iOS, device | More than 0.5 percentage point drop or 1.5x 28-day baseline | Release regression |
| Crash clusters | symbol, build, OS | New cluster with at least 2 users or repeated crash in 24 hours | Fast triage |
| Hangs and watchdog terminations | build, device, OS | 1.5x baseline or any new launch hang cluster | User experience failure not always shown as a crash |
| Launch failures | build, OS | Any sustained increase over baseline | App unusable before funnel events |
| HealthKit fetch errors | build, OS, permission state | 2x baseline or more than 1 percent of discovery attempts | Empty dashboard and trial loss |
| Discovery duration | device class, history size bucket | P95 exceeds an agreed budget or background task expires | Onboarding abandonment |
| Catalog load failure | build, storefront, paywall ID | More than 1 percent or 2x baseline | Trial and revenue loss |
| Trial start rate | acquisition source, surface, build | More than 20 percent relative drop | Funnel regression |
| Paywall-to-purchase rate | surface, product, build | More than 15 percent relative drop | Copy or purchase-flow regression |
| Pending purchase rate | product, storefront, build | New spike or pending over agreed time budget | False activation and support burden |
| Entitlement activation latency | product, build | P95 over 5 minutes or no transition after purchase | User sees paid flow without access |
| Restore success | build, storefront | Drop versus prior release | Returning subscribers blocked |
| Notification schedule health | build, Pro state | Daily request missing or stale IDs remain | Reminder UX and duplicate notifications |
| Widget or watch snapshot age | app version, device | Snapshot older than 24 hours for active users | Cross-device trust failure |
| ASC rating or review anomaly | version and release date | New negative cluster or material average drop | Release quality signal |

The numerical thresholds above are proposed starting points, not production SLOs. Establish the baseline from at least the prior 28 days and review thresholds after two releases.

### 9.3 Specific source-level watchdog risks

#### Notification cleanup

`NotificationService.cancelAll()` removes only `streaks.dailyReminder` (`Shared/Services/NotificationService.swift:101-125`). Broken-streak requests use IDs beginning with `streaks.broken.` (`Shared/Services/NotificationService.swift:10-13,101-119`). A Pro downgrade or data refresh can therefore leave old broken-streak notifications pending. Add a deterministic cleanup path that removes all matching broken IDs, and cancel a broken notification when the streak is revived or no longer relevant.

#### Background refresh visibility

`FitnessStreaks/App.swift` schedules a background app refresh and calls entitlement and store refresh. Add duration, success, failure, cancellation, and task-expiration logs with build and OS metadata. A background task that silently expires can cause stale widgets and missed notifications without a crash.

#### Stale cache and revoked access

`StreakStore` has a data-loss heuristic and falls back to cached history when HealthKit reads fail. Validate the distinction among revoked permission, no samples, delayed Health data, a genuine zero-activity day, and a stale cache. The UI should tell the user what happened and offer Health Settings or retry without making a medical interpretation.

#### Cross-device entitlement and snapshot lag

Watch and widget targets read shared state rather than querying RevenueCat directly. Validate a purchase, restore, expiration, downgrade, and product load on iPhone followed by immediate watch and widget refresh. A user should not be shown contradictory Pro state across surfaces.

#### Notification volume and duplicate scheduling

The daily reminder is replaced by a stable identifier, but broken streak notices use an event-specific identifier. Confirm that repeated refreshes do not create duplicate or obsolete requests and that time-zone and daylight-saving changes do not schedule a reminder at an unexpected time.

## 10. Agent documentation hygiene for Cursor, Claude, and Codex

### 10.1 What is current and useful

- `CLAUDE.md` is the project guide and describes the architecture, targets, HealthKit read-only model, App Group, streak engine, and review funnel (`CLAUDE.md:1-57`).
- `AGENTS.md` is a symlink to `CLAUDE.md`, so the two agent families share the same canonical instructions.
- `project.yml` is the XcodeGen source of truth for targets, bundle IDs, versions, RevenueCat linkage, and schemes.
- `ios27StreakFinder.md` is a dated audit and should remain useful only as historical evidence with its date visible.

### 10.2 What can mislead an implementation agent

| File or folder | Stale or conflicting content | Action for a later cleanup pass |
|---|---|---|
| `my-current-paywall-spec.md` | Large historical Grace Days design, yearly-only trial, dimensions that no longer match current code | Rename or move to archive and add a current pointer |
| `docs/astro-aso-setup.md` | Last pass 2026-05-25, old app name and old keyword plan | Mark historical or regenerate from current ASC data |
| `scripts/apply-streak-tracker-name.py` | Hardcoded `Streak Tracker: Fitness Habits` rename | Make it an explicit experiment tool with dry-run and current name input |
| `scripts/aso-fitness-locale-readout.py` and JSON | Old `Streak Tracker` or `Fitness Habits` name assumptions | Remove as source of truth or update after canonical-name decision |
| `docs/app-store-description.txt` | Parallel 9-metric copy and static prices | Generate from canonical metadata or label as source draft |
| `docs/support.html` | Last updated May 2 and missing current purchase and trial recovery guidance | Update after product truth is settled |
| `fastlane/Fastfile` | Lane description still says submit `1.2.4` while project is `1.2.8` (`fastlane/Fastfile:39` area) | Update operational text and add version checks |
| `archive/` | Historical audits and handoffs have old onboarding and Grace Days assumptions | Keep historical, add an index and a current-status pointer |
| ASC scripts under `scripts/` | Several scripts can mutate ASC and hardcode product IDs or past dates | Require dry-run, plan output, explicit apply, and idempotency |

No Cursor-specific `.cursorrules` or equivalent guide was found in the repository. This is not inherently a problem, but Cursor will fall back to the shared project files. Add a short current-agent contract to the canonical guide or a clearly named current docs page rather than creating three divergent instruction files.

### 10.3 Recommended current-agent contract

The implementation agent should be told:

1. Read `CLAUDE.md`, `project.yml`, the current audit, and the relevant source before editing.
2. Treat `archive/` and dated audits as historical unless a current pointer says otherwise.
3. Treat `project.yml` as the XcodeGen source and rerun XcodeGen after source or project changes.
4. Never use a production RevenueCat key in a simulator.
5. Use a dry-run for every ASC or metadata mutation and print the exact files and remote records that would change.
6. Do not put raw HealthKit values, medical inferences, or personal identifiers into RevenueCat attributes or logs.
7. Preserve the legal and wellness boundaries in `docs/terms.html`.
8. Add or update tests for pending transactions, catalog failure, restore, free caps, notification cleanup, and all paywall surfaces.
9. Keep current product vocabulary in one source and explicitly label experiments.

## 11. A/B test backlog

Run one variable at a time, keep product truth and legal disclosure constant, and segment by version, storefront, acquisition source, and trial eligibility.

| Test | Control | Variant | Primary metric | Guardrails |
|---|---|---|---|---|
| Onboarding timing | Full-screen trial immediately after selection | Dashboard first, delayed trial sheet after first value | Discovery-to-trial start | D1, D7 retention, onboarding completion |
| Trial CTA plan | Annual-first direct trial | User chooses annual or monthly before CTA | Trial starts and 7-day paid conversion | Cancellation, refund, monthly mix, revenue per install |
| Cap explanation | Current over-cap selection and later trim | Show exact free cap and rows retained before offer | Trial start and free completion | Selection abandonment, support complaints |
| Paywall context | Generic hero | `Keep all N discovered streaks`, `See full history`, or `Revive recent streak` | Paywall-to-trial or purchase | D7 retention, close rate, refund rate |
| Default plan | Yearly selected | Monthly selected or no default | Purchase rate and revenue per install | Trial conversion, lifetime cannibalization |
| Feature order | Auto-save first | Heatmap, alerts, or custom tracking first | Purchase start | Entitlement activation and refund |
| Trial sheet navigation | Direct CTA plus `See all plans` | Plan cards inline on first sheet | Trial start and plan selection | Cognitive load, dismissal |
| Heatmap gate | Blurred locked heatmap | Static preview with one clearly labeled unlock action | Detail-to-paywall conversion | Accessibility, perceived deception, retention |
| Broken recovery | Direct revive trial | Explain free recovery limitation and show plans | Recovery completion | False revival, support complaints |
| Review moment | Hero growth or goal met | First completed selected streak or successful recovery | Review intent and feedback intent | D7 retention, interruption, negative feedback |
| Reminder education | Pro-gated toggle only | Explain the reminder with a preview before permission | Notification opt-in and return rate | Permission denial, notification complaints |
| Landing page | Current hidden-streak hero | HealthKit discovery or iPhone plus Watch hero | Store click-through and download conversion | Refund and trial cancellation by source |

For each experiment, persist the variant in the impression ID or a stable experiment attribute. Do not infer a variant from screen text after the fact.

## 12. Deterministic checks a future non-AI scanner should implement

This audit does not create the scanner because the current request limits changes to this audit file. The following is the implementation contract for a later script that can catch the highest-confidence issues without AI.

### 12.1 Local repository checks

1. Parse `project.yml` and verify marketing version, build, bundle IDs, App Group, deployment targets, package versions, and target membership.
2. Parse `FitnessStreaks/FitnessStreaks.storekit` and compare product IDs, subscription periods, local prices, trial duration, and product descriptions with a checked-in canonical product file.
3. Scan all Fastlane locale files for required fields, character limits, empty values, missing URLs, static price tokens, old brand names, old product vocabulary, and unsupported metric counts.
4. Verify all metadata URLs use the chosen canonical support, privacy, terms, and landing hosts.
5. Verify all App Store links include App Store ID `6762699692`, and flag old slugs for review.
6. Extract metric names from `Shared/Models/StreakMetric.swift`, HealthKit query types, support, privacy, README, App Store descriptions, and landing JSON-LD. Report the counts and the exact names rather than guessing a single number.
7. Extract premium vocabulary such as `Grace Day`, `auto-save`, `freeze`, `planned freeze`, and `Streaks+`, then report files that use retired terms.
8. Compare the free tracked cap and custom-streak cap from source constants, tests, UI copy, metadata, support, and terms.
9. Compare product IDs in `StoreKitService`, StoreKit config, ASC scripts, tests, and any RevenueCat configuration. Flag hardcoded numeric ASC IDs for manual verification.
10. Report operational scripts that mutate ASC or keyword services without `--dry-run`, explicit apply, plan output, or an idempotency check.
11. Scan for production RevenueCat keys in simulator or test fixtures and fail the check if one is configured for a simulator run.
12. Scan for `PurchaseOutcome.pending` branches and verify that they do not emit a confirmed-purchase event or consume irreversible value.
13. Scan notification identifiers and cleanup methods. Require cleanup for every prefix created by the app.
14. Scan dated docs and release strings, reporting docs older than a configurable threshold that mention current product behavior.
15. Run a no-em-dash style check for new agent-facing docs because the repository instruction forbids that punctuation.

### 12.2 External read-only checks

With explicit credentials and a dry-run mode, the future script can:

- pull ASC app version status, review issues, metadata, product IDs, prices, offer eligibility, ratings, crash diagnostics, and App Analytics exports;
- pull RevenueCat offerings, entitlement configuration, trial and subscription summaries, and paywall impression data;
- check HTTP status, redirects, canonical tags, and content hashes for landing, support, privacy, and terms URLs;
- compare the public App Store title, price disclosure, and current version with the local source-of-truth values.

Every external check should produce a timestamped JSON report and never mutate ASC, RevenueCat, the website, or metadata unless an explicit apply mode is supplied.

### 12.3 Release watchdog output

The future macOS watchdog should emit a compact report with:

- release and baseline build;
- crash-free users, crash-free sessions, crash clusters, hangs, watchdog terminations, launch failures;
- catalog, purchase, pending, restore, and entitlement latency rates;
- trial starts and paywall conversion by stable surface ID;
- App Analytics downloads and product-page conversion by source;
- stale widget or watch snapshot signals if a permitted export exists;
- a list of new static consistency findings;
- `OK`, `WARN`, or `ACTION_REQUIRED` for each rule.

It should scaffold email or other notification delivery but keep delivery disabled by default until reviewed.

## 13. Implementation order for the next agent

### Phase 0, establish truth before changing copy

1. Pull production ASC and RevenueCat product IDs, prices, subscription group, entitlement identifier, trial eligibility, and storefront behavior.
2. Resolve the exact ASC review issues link.
3. Decide the canonical app name, supported-metric count, free tracked cap, custom-streak cap, and premium vocabulary.
4. Mark `my-current-paywall-spec.md`, `docs/astro-aso-setup.md`, old ASO scripts, and historical audits as current, experiment, or archive.

### Phase 1, fix high-confidence commercial consistency

1. Correct or remove stale landing-page prices and rating JSON-LD.
2. Make App Store links use the stable numeric ID and settle the canonical host.
3. Remove prices from App Store descriptions unless a controlled localization update process is intended.
4. Align product and trial terms across paywall, onboarding, trial sheet, metadata, support, and terms.
5. Resolve the custom-streak 1 versus 3 contradiction.

### Phase 2, instrument and harden the funnel

1. Add the approved low-cardinality attributes and funnel events.
2. Separate pending, confirmed, active, cancelled, and failed purchase states.
3. Add catalog failure and retry telemetry.
4. Add restore status on every restore route.
5. Make entitlement allowlisting explicit.
6. Clean all broken-streak notification identifiers during refresh, revival, downgrade, and settings changes.

### Phase 3, test user experience and experiments

1. Run the paywall accessibility and device matrix.
2. Run the onboarding matrix for no data, partial permissions, cap boundary, trial eligible, trial ineligible, catalog failure, purchase pending, and restore.
3. Run cross-device purchase, downgrade, widget, and watch tests.
4. Choose one A/B test with a stable control ID and predeclared guardrails.
5. Compare the first release with the 28-day baseline before adding a second experiment.

### Phase 4, maintain the scanner and watchdog

1. Add deterministic local checks to CI or a macOS launch agent in disabled-notification mode.
2. Store reports outside the app source tree or in an explicitly ignored reports directory.
3. Run after every metadata or app release change and daily for seven days after a production release.
4. Review alerts manually before enabling email.

## 14. Validation matrix

| Area | Scenario | Expected result |
|---|---|---|
| HealthKit | First launch, permission accepted | User sees discovery progress and a useful result |
| HealthKit | Permission denied or partial | Clear empty or limited-data guidance and Health Settings path |
| HealthKit | No samples | No misleading paywall pressure before value explanation |
| HealthKit | Revoked permission after cached data | Cached data is not silently presented as current; user sees a recoverable state |
| Discovery | 0, 1, 3, 5, and 6 candidates | Counts, selection, cap explanation, and trial copy remain accurate |
| Trial | Annual eligible | Trial days, after-trial price, billing term, and CTA agree |
| Trial | Monthly eligible or ineligible | Plan availability and copy reflect live eligibility |
| Trial | No eligible trial | Full paywall or clear free path, no false “free trial” claim |
| Catalog | Timeout, error, empty offerings | Retry, free continuation, and telemetry distinguish outage from dismissal |
| Purchase | User cancel | No access grant, selection preserved, no error that implies payment |
| Purchase | Pending approval | Pending state is visible and no irreversible entitlement-dependent action is consumed |
| Purchase | Confirmed purchase | Entitlement activates, paywall dismisses, dashboard and watch/widget state update |
| Purchase | Restore active | Status is visible and all purchased features unlock |
| Purchase | Restore empty | Status says no active purchase and free state is intact |
| Purchase | Billing issue or expiration | Access and copy reconcile after refresh |
| Paywall | All eight surface IDs | Impression, context, dismissal, selection, and purchase events identify the surface |
| Paywall | Dynamic Type and VoiceOver | No clipped legal or purchase text; product terms are announced |
| Review | Positive, negative, not now | Correct route, no interruption during onboarding or purchase, intent recorded locally or through approved telemetry |
| Notifications | Enable, disable, Pro downgrade, revive | Only relevant requests remain pending |
| Widgets | App refresh and stale cache | Snapshot age and fallback state are understandable |
| Watch | Purchase, restore, downgrade | Pro state and snapshot converge after a refresh |
| Legal | Current price and trial change | Terms, paywall, support, metadata, and site remain semantically consistent |
| Agents | Fresh Cursor, Claude, and Codex session | Canonical guide is clear, archive is not mistaken for current behavior, and no mutation runs without dry-run intent |

## 15. Final evidence and non-findings

### Directly supported findings

- Landing-page price values differ from local StoreKit and App Store description values.
- Local brand names differ across current and historical sources.
- Local metric counts and lists differ across source, README, App Store copy, support, privacy, and landing JSON-LD.
- Local StoreKit has monthly and yearly introductory offers, while the paywall spec says yearly only.
- Pending purchase is treated as access by current code paths.
- Catalog failure falls back to free onboarding without a remote funnel event.
- RevenueCat custom paywall impressions exist, but custom attributes and broader funnel events do not appear in source.
- Custom-streak code allows three while a UI string says one.
- Broken notification cleanup removes the daily identifier but not the broken prefix.
- Support is older than terms and privacy and lacks current purchase-flow guidance.
- The repository has a shared Claude/agent guide but no Cursor-specific guide, and several dated or historical docs contain retired behavior.

### Not concluded because evidence is missing

- Whether production ASC prices currently match the local StoreKit values or the landing page values.
- Whether the visible ASC review issues are blocking.
- Which App Store metadata or screenshots currently produce downloads.
- Which paywall surface produces the most trials or revenue.
- Current Streak Finder ratings, review velocity, crash rate, hang rate, or retention.
- Whether RevenueCat has production custom attributes configured outside this repository.
- Whether the GitHub Pages and `jackwallner.com` URLs redirect consistently in every storefront.

### Explicit scope exclusions

- No source or configuration fix was applied.
- No ASC, RevenueCat, website, metadata, notification, or email mutation was performed.
- No notification delivery was deployed.
- No claim is made that RevenueCat purchase processing contradicts the local HealthKit privacy story; that comparison was intentionally excluded from findings per request.
- No treatment, diagnosis, prevention, or cure claim is recommended anywhere in the implementation backlog.

