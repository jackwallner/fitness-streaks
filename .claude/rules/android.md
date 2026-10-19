---
paths: ["android/**"]
---

# Streak Finder Android

Native Kotlin/Compose phone port in `android/`, package and namespace `com.jackwallner.streaks`, version 1.3.1 (code 3), min SDK 28, target 36. iOS remains the screen and paid-boundary specification.

## Build and test

Use the checked-in wrapper with JDK 21 (AGP 9.4.1), installed here at `~/.jdk/jdk-21.0.12.1+1/Contents/Home`. SDK: `~/Library/Android/sdk`. Put Test Store/Play SDK keys and upload signing properties only in ignored `android/local.properties`, following `local.properties.example`. Existing upload key: `~/.android/keystores/streaks-upload.p12`; signing credentials stay outside git.

Run on the Pro locally, never SSH to the Air:

```sh
cd android
export JAVA_HOME="$HOME/.jdk/jdk-21.0.12.1+1/Contents/Home"
./gradlew --no-daemon --max-workers=1 testDebugUnitTest assembleDebug assembleDebugAndroidTest assembleRelease bundleRelease assembleQa lintRelease
```

The connected reviewer case requires the private code in the instrumentation `reviewCode` argument. Supply it through a local harness that reads the credentials file and redacts output. Never paste it into a logged command or commit it. Reject zero-test device runs.

The temporary Google Play API 36 AVD for acceptance is `sol-streaks`, serial `emulator-5584`. Reuse it while running, check `adb -s emulator-5584 shell getprop sys.boot_completed`, and stop only it with `adb -s emulator-5584 emu kill`. Run at most one owned AVD. Launch headlessly with `emulator -avd sol-streaks -port 5584 -no-window -no-audio -no-boot-anim -no-metrics`. Delete this owned temporary AVD after acceptance. Never use `adb kill-server`.

## Data and platform differences

Health Connect replaces read-only HealthKit. Daily steps, active energy, distance and flights use deduplicated aggregates. Custom step goals can select a one-hour time window. Workout minutes subtract pause segments; workout-specific distance comes from Health Connect distance aggregates. Sleep belongs to the end day; overlapping sleep/mindfulness intervals count once. Cardio minutes estimate time above 100 bpm, capping sample gaps at 30 seconds.

Stand hours have no Health Connect equivalent and are unavailable. Mindfulness, past-history and background access depend on provider feature support and individual grants. Without past-history access the import is limited to 30 days. Watch, complications and widgets are deferred. Automatic discovery is daily-only, matching current iOS; custom timed goals remain supported.

Activity stays local and is excluded from Android backup. Permission changes clear cached activity and saved-run metadata before import. Disconnect revokes access and deletes local history without deleting Health Connect records. Background work and inexact notifications require Streaks+; optional background health permission is checked before a worker reads.

## Billing and review

Free tracks three streaks and permits three custom goals. Streaks+ unlocks unlimited tracking, full history, saves, freezes and proactive alerts. Use the existing RevenueCat project `a635c59c`, Play app `appb51d6aa64c`, and default offering. Product IDs match iOS: `com.jackwallner.streaks.monthly`, `.yearly`, `.lifetime`; Play subscriptions use monthly/yearly base plans. Entitlement behavior matches iOS (active project entitlement grants access).

Reviewers long-press the Settings version text and enter the private code stored in `~/.streaks_credentials` (`STREAKS_PLAY_REVIEW_CODE`). Only its SHA-256 is supplied through ignored `PLAY_REVIEW_CODE_SHA256`; activation persists the digest, and code rotation invalidates the grant. Never print or commit the code.

Debug uses only Test Store. QA is R8-optimized with no billing key and the release no-op launch options. Never install a production-key release on the emulator. Test Store purchases are explicitly free test transactions. Pending/cancelled purchases do not unlock. Review requests occur directly after a positive moment; Settings separates Rate and Send feedback.

`~/.rc-clean/apps.json` already contains an Android block for this package and the iOS platform filter. Existing Play service-account credentials are saved and confirmed; package registration is complete.

## Verification and Play state

2026-10-18: accepted base `e22ccba` is on main and the old WIP branch was deleted. The base passed 1,209 JVM and all 21 Pro device cases, including real Health Connect 5,000-step aggregate import, paused workout minutes, heart rate, permission revoke/cache clearing and free/paid boundaries. Light/dark/detail, free listing captures and the free Test Store lifetime purchase were inspected; the RevenueCat entitlement was confirmed. Test Store restore returns current CustomerInfo because that store has no restore implementation. Licensed Play purchase and restore remain pending.

Reviewer-access vc3 passes all 1,213 JVM cases and the additional actual-dialog device case (149.407 seconds): wrong code rejected, valid code entered through UI, grant survives RevenueCat refresh and StoreService recreation. The field uses Password keyboard type, disables autocorrect and masks entry. The private code was rotated after QA exposed suggestions from the earlier field. Only the current digest ships. Signed vc3 APK/AAB target36, signatures, ZIP and all four native ELF 16 KB alignments pass. Optimized vc3 QA opens onboarding despite every debug unlock/seed/skip flag, and its capture was inspected. The full build and release lint pass, completing the accepted vc3 update.

Play app `4972839548045906217` in E3 Apps currently serves internal vc2, not reviewed, at https://play.google.com/apps/internaltest/4701382895236577639. Production is draft vc2. The Play reviewer form already has the current vc3 code, so replace the uploaded build before review. All three products and eligible seven-day trials are active. Listing/art/four free captures, privacy, reviewer instructions, ads, adult audience, advertising ID, government, financial, Data safety, full health declaration/ten permission explanations, Health & Fitness category and 178 production countries/regions are saved. Managed publishing is off. Content rating awaits Jack's approval for IARC terms. Pre-launch overview has no report yet. Quit Zyn was in review at the earlier pacing check; recheck it before any production submission. See `project-docs/android/play-console.md`.
