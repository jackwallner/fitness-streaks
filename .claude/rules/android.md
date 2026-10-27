---
paths:
  - "android/**"
---
# Streak Finder Android

Native Compose phone port, package `com.jackwallner.streaks`, version 1.3.1, versionCode 1, minSdk 28, target/compileSdk 36. No Play uploads or Console changes in this task.

## Build

From `android/`, run `fm-gradle testDebugUnitTest assembleQa lintRelease` (runs on jmbp, copies outputs, reports and test results back). Only the signed `./gradlew assembleRelease bundleRelease --no-daemon --max-workers=2` runs on the Air, with its local JDK 17. Signing and public SDK keys are in ignored `local.properties`; upload key is `~/.android/keystores/streaks-upload.p12`, passwords in `~/.fitness-streaks_credentials`. Never copy release signing or Play keys to Pro.

Debug uses RevenueCat Test Store. Release requires the Play `goog_` key and upload signing. QA runs the optimized release implementation with no billing key. Debug-only intent fixtures and forced entitlement are excluded from release and QA. Any active project entitlement unlocks Streaks+, pending purchases do not.

RevenueCat project `a635c59c`, Play app `appb51d6aa64c`. Original monthly/yearly/lifetime product IDs retained, subscription base plans `monthly` and `yearly`. Three mappings attached to the original entitlement/offering. `rc-clean` registers the Play app with `filter_platform: android` on Air and Pro. Play app credentials, product activation, Console forms and licensed Play purchase verification are deferred.

## Pro runtime

Only emulator host: `ssh jackwallner@192.168.4.25`, strict default host verification. SDK `/Users/jackwallner/Library/Android/sdk`, JDK `$HOME/.jdk/jdk-21.0.12.1+1/Contents/Home`.

Create only the temporary `sol-streaks` AVD from `system-images;android-36;google_apis_playstore;x86_64`. Export the JDK before `cmdline-tools/latest/bin/avdmanager create avd -n sol-streaks -k 'system-images;android-36;google_apis_playstore;x86_64' -d pixel_7`. Boot `emulator -avd sol-streaks -port 5584 -memory 3072 -cores 2 -no-window -no-audio -no-boot-anim -no-metrics -no-snapshot -gpu host -feature -Vulkan`. Host GPU avoids the old Intel Pro's software-renderer ANRs. Confirm `adb -s emulator-5584 emu avd name` is `sol-streaks` and `adb -s emulator-5584 shell -n getprop sys.boot_completed` is `1`.

Run `./scripts/test-android-pro.sh`: sync to `~/tmp/sol-streaks`, copy only the Test Store key, run JVM and orchestrated connected tests with `ANDROID_SERIAL=emulator-5584`, inspect XML counts and pull results. Keep other AVDs untouched. Capture native 720x1440 images with `scripts/capture-android-pro.py`. Use new-task/clear-task launches for each debug scene. Never boot locally.

After verifying the AVD name, stop only `adb -s emulator-5584 emu kill`, confirm its serial and process are absent, then delete only this run's `sol-streaks` AVD and `~/tmp/sol-streaks`. Never use an unqualified emulator kill or ADB server kill.

## Data and parity

The Swift engine is canonical. `python3 scripts/sync-android-parity.py` compiles original sources to export daily/discovery expectations and the 12-metric, 34-workout catalog. The exporter strips only UI imports/properties and replaces the settings container with its pure key helper. Rerun after iOS model/engine changes.

Health Connect is read-only. Aggregate steps/calories/distance/floors; workout minutes exclude pauses; sleep intervals are unioned and credited to their end date. Cardio Minutes match the original approximation above 100 bpm. Stand hours are unavailable; no fabricated Apple Watch data. Mindfulness is feature gated. Only workout types with a distinct Android type appear in the custom picker. No automatic hour-window discovery, matching current iOS. No Wear OS or widget port.

Permission changes clear derived history before reading again. A transient empty import preserves the last good cache without falsely breaking streaks, matching iOS. Background refresh requires optional background permission; reminder work is inexact and uses the chosen time. Free: three tracked and three custom streaks. Pro: unlimited, saves, freezes, history, proactive notifications. Original onboarding intent restores after upgrade. Replay tutorial, direct system review after a positive moment, separate Rate/Send feedback actions.

Listing and offline product plan: `play-assets/`, `project-docs/android/`. Public Android policies: `docs/android/`. Never put secrets or private review contact details in these files.
