# Google Play preparation

Package: `com.jackwallner.streaks`. Listing: Streak Finder. Developer: E3 Apps, account `8314164911785412040`.

## Current state

Created in E3 Apps on 2026-10-18, Play app ID `4972839548045906217`. The package is registered. Version code 2 is uploaded. Internal testing is active and available to testers, not reviewed. Production remains a vc2 draft. All three iOS-matching products, monthly/yearly base plans, eligible seven-day trials and regional pricing are active. Listing, icon, feature graphic, four real free-screen captures and contact details are uploaded. Category is Health & Fitness. Production availability covers 178 countries/regions. The existing internal tester email list is selected. The actual Console opt-in link is https://play.google.com/apps/internaltest/4701382895236577639. Managed publishing is off.

Privacy, reviewer access, ads, health, adult target audience, advertising ID, government, financial features and Data safety declarations are saved. Reviewers can continue without Health Connect, then long-press the Settings version label and enter the code saved in the private Play app access form. The current code is in the local credentials file, never in this repository.

## Remaining release work

1. Reviewer-access vc3 passes 1,213 JVM cases, the actual-dialog reviewer device case, signed artifact checks and optimized QA debug-hook isolation. The full build and release lint pass. Upload vc3, publish it to internal testing and replace the production draft. The current Play reviewer code matches vc3; internal vc2 contains the previous digest.
2. Content rating is pending Jack's approval to accept IARC's Terms of Use. The questionnaire explicitly requires a new legal agreement, so leave it unchecked until approved.
3. Internal release validation and rollout are complete. Verify licensed no-charge Play purchase and restore, and inspect the pre-launch report. A Google Play tester must already be signed in; never enter a password or OTP.
4. The full three-step Health Connect declaration is saved, including all ten read/history/background permission explanations. Production preview now reports no errors and only the missing native debug symbols warning. Countries/regions are already selected.
5. Recheck Publishing overview and the fleet tracker before production review. Quit Zyn was in review at the earlier 2026-10-18 check. Keep managed publishing off and leave this production release as a draft until the preceding review clears and pacing permits it. Do not claim ready while content rating or other required checks remain.

Use the dedicated Play Chrome task tab. Standard new-tab attachment can time out, while MCP DOM access through the separate same-origin task window works. Confirm E3 Apps and developer ID before each mutation.

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
