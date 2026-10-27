# Android verification

Build preparation, 2026-10-18. No Play upload, Console app, publication or review submission.

## Source parity

- Native Compose phone port of onboarding, calibrated discovery, primary streak and badges, detail, calendar history, per-weekday statistics, tracked/custom goals, saves, planned freezes, stats, settings, trial/paywall, restore, separate review/feedback and privacy.
- Original Swift `StreakEngine`, metric/workout catalog and models compiled by `scripts/sync-android-parity.py`. Generated fixtures include 1,080 daily computations and 96 complete discovery scenarios. Tests compare thresholds, ranking, stable keys, lengths, dates, progress, completion, rates and grace behavior.
- Free cap: three tracked goals, three custom goals. Pro unlocks unlimited goals, automatic saves, planned freezes, history and proactive alerts. Upgrade restores the original full onboarding selection. Pending purchases never unlock content.
- Original light/dark arcade colors and JetBrains Mono fonts. Zero rounded panel corners and two-pixel borders.

## Health Connect

Read-only. Steps, calories, distance and floors use Health Connect aggregation. Workout minutes remove pause intervals. Sleep intervals are unioned and credited to their end date. Cardio Minutes preserve the Swift approximation: above 100 bpm, first sample five seconds, subsequent elevated-sample gaps capped at 30 seconds. Mindfulness uses the feature-gated record when available.

Stand hours have no equivalent and stay unavailable. Workout minutes are labeled as recorded workout duration, not Apple Exercise time. Android distance is the total distance shared with Health Connect. Workout picker includes only types with an identifiable Android record. No automatic hour-window discovery, matching the current Swift engine. Wear OS and widgets are deferred.

Permission changes clear derived cache before the next read. Transient missing past days can merge with valid cache; a suspicious empty recent window keeps last known data without detecting false breaks. Disconnect revokes permissions and clears local activity history and saves. Health data never leaves the device. Optional history permission enables up to 400 days; otherwise import is limited to 30 days. Optional background permission enables hourly refreshes; reminders use inexact work at the selected time.

Aggregate test setup uses the real Health Connect permission UI for the fixture writer. Shell-only write grants skip aggregate-priority initialization, as documented in [AOSP aggregation test setup](https://android.googlesource.com/platform/packages/modules/HealthFitness/+/898db3279ba8f63d4c9a6cd18905b7f121948f3e/tests/cts/utils/HealthConnectTestUtils/src/android/healthconnect/cts/utils/TestUtils.java). The production bridge keeps unfiltered aggregate reads and never sums raw steps as a fallback.

Primary references: [Health Connect aggregate data](https://developer.android.com/health-and-fitness/health-connect/aggregate-data), [mindfulness feature and permission](https://developer.android.com/health-and-fitness/health-connect/features/mindfulness).

## Artifacts and checks

Verification is running. Final counts, runtime evidence, signatures and alignment results are recorded here after checks complete. Local machine-specific XML reports and proof captures stay ignored under `android/verification/` and build outputs.

## Billing and deferred work

RevenueCat project `a635c59c`, Play app `appb51d6aa64c`. Three Play product mappings attached to the existing entitlement and offering. Debug uses Test Store; release uses the Play key; optimized QA uses no SDK key. Release configuration fails when signing or Play key is absent. Keys and upload key passwords stay outside git.

Offline proposed price ladder: USD 1.59 monthly, 11.99 yearly, 23.99 lifetime, approximately 20% below the iOS StoreKit reference, with seven-day acquisition trials and the fleet PPP curve. `scripts/play-products.py` printed the offline plan only.

Deferred Console app, product activation, trial offers, authorized Play credential link, content/health/Data Safety forms, licensed Play Billing tests, internal-track upload, pre-launch checks and review submission.
