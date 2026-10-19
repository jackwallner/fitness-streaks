# Google Play preparation

Package: `com.jackwallner.streaks`. Listing: Streak Finder. Developer: E3 Apps, account `8314164911785412040`.

## Console steps remaining

Created in E3 Apps on 2026-10-18, Play app ID `4972839548045906217`. The package is registered and available through the Publisher API. Use the dedicated Play Chrome task tab. The account is signed in; standard new-tab attachment is timing out, while MCP DOM access through the task window works.
1. App created as Streak Finder, English (United States), App, Free. Confirm E3 Apps and the developer ID above before each Console step. Stop for any new legal agreement or authentication challenge.
2. Upload `android/app/build/outputs/bundle/release/app-release.aab` through the Publisher API, then create internal and production draft releases. Use Google Play App Signing with the existing upload certificate. Do not replace the upload key.
3. Run `scripts/play-products.py` with the existing service-account file in `PLAY_SERVICE_ACCOUNT_JSON`. It creates the iOS-matching monthly, yearly and lifetime IDs, regional PPP pricing and eligible one-week trials. Inspect prices and product state.
4. Stage `play-assets/` using `play_stage.py listing`, contact `jackwallner@gmail.com`, website `https://jackwallner.github.io/fitness-streaks/`. Stage internal and production draft releases with `play_stage.py release com.jackwallner.streaks 1 internal production`.
5. Finish App content and store settings below. Complete and roll out internal testing, copy its actual tester opt-in link, and verify licensed no-charge Play purchase and restore plus the pre-launch report.
6. Check Publishing overview and the fleet tracker. Quit Zyn was confirmed in review in Console on 2026-10-18. Keep managed publishing off. Leave production as a draft, "Ready: send in its pacing slot", until the preceding review clears and the weekly pacing permits this app. Then send its changes for review and verify status.

## App content answers from this build

- Privacy: `https://jackwallner.github.io/fitness-streaks/android/privacy-policy.html`.
- Terms: `https://jackwallner.github.io/fitness-streaks/android/terms.html`.
- No ads, advertising ID, login, messaging, financial features or government affiliation. Adult target audience (18+). Optional Streaks+ is sold through Play; the free core requires no credentials. App access instructions: continue without Health Connect, or grant read access to populated Health Connect records; free tracks three streaks. Explain the optional paid features to reviewers.
- Health: Activity and fitness, sleep tracking and optional mindfulness tracking. This is habit tracking, with a medical disclaimer, and no diagnosis or treatment claims.
- Health permissions: read steps, active calories, distance, floors, exercise, sleep, heart rate and supported mindfulness to discover user-selected activity streaks and calculate daily goal progress. Heart rate estimates cardio minutes. Optional history permission enables more than 30 days for streak discovery/history. Optional background permission refreshes paid at-risk reminders. No writes, advertising use, data sales or off-device health transfers.
- Data safety: RevenueCat receives purchase history, anonymous app-user identifiers, app/device information and paywall interaction attributes for billing, entitlement management and conversion diagnostics. No health values leave the device. No account is created. Purchase/interaction data is transmitted over HTTPS; deletion requests go to the support email. Declare these actual SDK transfers rather than copying the iOS labels. No advertising-ID collection is enabled.
- Content rating: complete the actual IARC questionnaire for a health/habit utility with no violence, gambling, user-generated content or unrestricted browsing. Stop if submitting requires a new legal agreement.

## RevenueCat

Existing project `a635c59c`, Play app `appb51d6aa64c`, entitlement `Fitness Habits - Streak Finder Pro`, offering `default`, packages `$rc_monthly`, `$rc_annual`, `$rc_lifetime`. Play products and entitlement/package mappings already exist in RevenueCat. Existing service-account credentials saved and confirmed on 2026-10-18. Validate Play credentials again after package registration. No service-account grant was created. The local rc-clean registry already has an Android block and iOS platform filtering.

## Sources

- [RevenueCat Data Safety guidance](https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety)
- [Android health permission guidance](https://support.google.com/googleplay/android-developer/answer/12991134)
- [Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
