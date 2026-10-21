# Google Play assets

Listing text for 50 Play locales is under `metadata/android/<locale>` (fastlane supply layout; en-US is the live source of truth, the other locales are native copy built from the iOS keywords, and each non-English description says the app is in English). Check with `scripts/validate-play-listing.py`. Artwork is RGB PNG: 512 x 512 icon, 1024 x 500 feature graphic and four 1080 x 1920 phone screenshots. Screenshots frame actual 720 x 1440 captures from the owned sol-streaks emulator on 2026-10-18. Sample activity illustrates the actual app screens. All listing captures show free screens, with no paid test unlock, purchase dialog, debug banner or Test Store pricing.

Console declarations and remaining release steps: [Play preparation](../project-docs/android/play-console.md).
