---
paths: ["android/**"]
---

# Streak Finder Android

Native Kotlin/Compose phone port in `android/`, package and namespace `com.jackwallner.streaks`, version 1.3.1 (code 1), min SDK 28, target 36. iOS remains the screen and paid-boundary specification.

## Build and test

Use the checked-in wrapper with JDK 21 (AGP 9.4.1), installed here at `~/.jdk/jdk-21.0.12.1+1/Contents/Home`. SDK: `~/Library/Android/sdk`. Put Test Store/Play SDK keys and upload signing properties only in ignored `android/local.properties`, following `local.properties.example`. Existing upload key: `~/.android/keystores/streaks-upload.p12`; signing credentials stay outside git.

Run on the Pro locally, never SSH to the Air:

```sh
cd android
export JAVA_HOME="$HOME/.jdk/jdk-21.0.12.1+1/Contents/Home"
ANDROID_SERIAL=emulator-5584 ./gradlew --no-daemon testDebugUnitTest connectedDebugAndroidTest assembleRelease bundleRelease assembleQa lintRelease
```

The temporary Google Play API 36 AVD for acceptance is `sol-streaks`, serial `emulator-5584`. Reuse it while running, check `adb -s emulator-5584 shell getprop sys.boot_completed`, and stop only it with `adb -s emulator-5584 emu kill`. Run at most one owned AVD. Launch headlessly with `emulator -avd sol-streaks -port 5584 -no-window -no-audio -no-boot-anim -no-metrics`. Delete this owned temporary AVD after acceptance. Never use `adb kill-server`.

## Data and platform differences

Health Connect replaces read-only HealthKit. Daily steps, active energy, distance and flights use deduplicated aggregates. Custom step goals can select a one-hour time window. Workout minutes subtract pause segments; workout-specific distance comes from Health Connect distance aggregates. Sleep belongs to the end day; overlapping sleep/mindfulness intervals count once. Cardio minutes estimate time above 100 bpm, capping sample gaps at 30 seconds.

Stand hours have no Health Connect equivalent and are unavailable. Mindfulness, past-history and background access depend on provider feature support and individual grants. Without past-history access the import is limited to 30 days. Watch, complications and widgets are deferred. Automatic discovery is daily-only, matching current iOS; custom timed goals remain supported.

Activity stays local and is excluded from Android backup. Permission changes clear cached activity and saved-run metadata before import. Disconnect revokes access and deletes local history without deleting Health Connect records. Background work and inexact notifications require Streaks+; optional background health permission is checked before a worker reads.

## Billing and review

Free tracks three streaks and permits three custom goals. Streaks+ unlocks unlimited tracking, full history, saves, freezes and proactive alerts. Use the existing RevenueCat project `a635c59c`, Play app `appb51d6aa64c`, and default offering. Product IDs match iOS: `com.jackwallner.streaks.monthly`, `.yearly`, `.lifetime`; Play subscriptions use monthly/yearly base plans. Entitlement behavior matches iOS (active project entitlement grants access).

Debug uses only Test Store. QA is R8-optimized with no billing key and the release no-op launch options. Never install a production-key release on the emulator. Test Store purchases are explicitly free test transactions. Pending/cancelled purchases do not unlock. Review requests occur directly after a positive moment; Settings separates Rate and Send feedback.

`~/.rc-clean/apps.json` already contains an Android block for this package and the iOS platform filter. Existing Play service-account credentials are saved and confirmed; package registration is complete.

## Verification and Play state

2026-10-18: all 1,209 JVM tests pass (1,176 Swift parity plus 33 behavior), and all 21 Pro device tests pass. Real Health Connect import verified 5,000 aggregated steps, a paused workout and heart-rate samples. Final signed APK/AAB vc1 target36 pass signature, package, ZIP and four native ELF 16 KB alignment checks. Release lint and optimized QA build pass. QA ignores all debug unlock/seed/skip flags. Light/dark, detail, loaded Test Store plans and purchase/restore captures were reviewed. A free Test Store lifetime purchase and active entitlement were confirmed through RevenueCat; the SDK restore call returns current CustomerInfo because Test Store has no store restore implementation. Licensed Play purchase and restore remain pending.

Play app `4972839548045906217` created in E3 Apps; version code 1 AAB uploaded. Product creation and App content declarations are in progress. Quit Zyn was confirmed in review, so production stays a draft until its pacing slot. See `project-docs/android/play-console.md`.
