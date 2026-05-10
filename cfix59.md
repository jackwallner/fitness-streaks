# cfix59 — UX Pain Points & Improvement Opportunities

*A rigorous user-experience review of FitnessStreaks v1.0.1, written from the perspective of someone actually using the app.*

---

## 1. First Launch & Onboarding

### 1.1 No Skip on Intro Screen
The very first screen (animated flame + "GET STARTED") has no way to skip ahead. If someone re-installs the app or already knows what it does, they're forced to sit through the full five-phase onboarding. On a fresh install there's no cached data, so fine — but on re-install after losing `hasCompletedSetup`, it's tedious.

**Fix:** Add a "SKIP" button on the intro phase that jumps straight to the dashboard (or at least to the intensity picker). Detect re-installs by checking if Apple Health already has data.

### 1.2 Tip Carousel Moves Too Fast
During the loading/discovery phase (Phase 3), the "Did You Know" tips rotate every 3.5 seconds. If the user has years of HealthKit data, this phase can last 30–60 seconds, meaning tips cycle through multiple times. Reading a tip, starting to process it, and having it yanked away is jarring.

**Fix:** Slow rotation to 5–6 seconds per tip. Add manual pagination dots so users can swipe between them.

### 1.3 No Back Button on Intensity Picker
After choosing an intensity (Phase 2), the flow advances to loading. There's no way to go back and change intensity during the loading phase, even though nothing irreversible has happened yet.

**Fix:** Offer a back button during loading. The user should be able to change their mind before streaks are committed.

### 1.4 HealthKit Denial Is Handled Well — But the "Skip" Path Is Confusing
If the user denies HealthKit access, they see "OPEN SETTINGS" and "SKIP" buttons. SKIP leads to an empty dashboard. What happens after that isn't explained — will they get prompted again? Will the app work without HealthKit? A new user has no mental model for what SKIP actually means.

**Fix:** Add a sentence: "You can grant access later from Settings. Without Health data, no streaks can be tracked."

### 1.5 Streak Selection Is Overwhelming
Phase 4 shows every discovered streak in a long toggle list. A user who ran the engine on 365 days of history might see 20–30 streaks — steps, exercise, stand, energy, workouts, mindfulness, sleep, distance, flights, intensity, cardio, plus time-window variants of each. The "SELECT ALL" / "START · N STREAKS" buttons help, but the list itself has no organization — no grouping by metric, no indication of which are "core" vs. "exotic."

**Fix:** Group by metric family. Show core metrics (steps, exercise, stand, energy, workouts) in a "Recommended" section at the top, collapsible sections for others. Pre-select only the recommended ones (which you already do).

---

## 2. Daily Dashboard Experience

### 2.1 No Pull-to-Refresh
This is the single biggest missing affordance. Every iOS user expects to pull down on a scrollable list to refresh. The only way to refresh is a small 36×36pt gear-icon button in the top bar. I have to scroll all the way up to find it if I've been looking at my badges.

**Fix:** Add `.refreshable { await store.load() }` to the ScrollView.

### 2.2 Entire Dashboard Vanishes During Refresh
When I tap refresh (or the app refreshes itself), my hero card and all my badges instantly disappear and are replaced by a loading screen — a flame icon and "LOADING HEALTH..." text. Every. Single. Time. This is disorienting. I was looking at my 47-day steps streak, now it's gone and a flame is spinning.

**Fix:** Show a subtle loading indicator (like a thin progress bar or a pulsing dot in the top bar) while keeping existing content visible. Only replace content if the data actually changes.

### 2.3 Timestamp Is Static — "2 min ago" Stays "2 min ago" Forever
The last-updated timestamp at the top (e.g., "updated 2 min ago · apple health") never updates. If I open the app at 8 AM, refresh once, and check again at noon, it still says "4 hours ago." This makes me doubt whether the data is fresh. Did it auto-refresh? Did I miss something?

**Fix:** Use `Text(timerInterval: ...)` or a `TimelineView` to keep the relative timestamp live.

### 2.4 Settings Gear and Refresh Button Scroll Away
The top bar (gear icon, refresh button, "STREAK FINDER" title) is inside the ScrollView — not pinned. If I scroll down to see my badges, I lose access to settings and refresh. I have to scroll all the way back up. This is especially annoying when I want to quickly change a setting after looking at a specific badge.

**Fix:** Pull the top bar out of the ScrollView into a fixed-position toolbar, or use `.safeAreaInset(edge: .top)` to keep it pinned.

### 2.5 Visual Misalignment — 16px vs 6px Padding
The top bar text uses 16px horizontal padding, but every card below it (hero, badges, "FIND MORE STREAKS" button) uses 6px. The left edges don't line up. "STREAK FINDER" sits 10px to the right of the hero card's left edge. This is visually sloppy on a screen designed around alignment.

**Fix:** Use consistent `.padding(.horizontal)` — 16px everywhere, or move the top bar to match the cards.

### 2.6 Broken Streak Banner Has No Tap Affordance
When a streak breaks, a red/amber banner appears: "STEPS · BROKEN · 14 days". It's tappable (opens the BrokenStreakSheet), but there's no visual hint — no chevron, no arrow, no "TAP TO RECOVER" text. I might just read it as an informational notice and miss the recovery flow entirely.

**Fix:** Add a trailing chevron or change the label to "TAP TO RECOVER" or "›" at minimum.

### 2.7 At-Risk Banner Feels Out of Place
The "! AT RISK" banner uses an exclamation mark that clashes with the retro/pixel aesthetic. The rest of the app is deliberate and stylized — this banner feels like a debug message. Also, the layout doesn't use the full width — the trailing text just ends, leaving dead space.

**Fix:** Replace "! AT RISK" with a pixel-appropriate icon (⚠️ or a custom pixel icon). Fill the width properly.

### 2.8 Empty State Buttons All Look Equal
When the dashboard is empty (no streaks), four buttons appear: FIND MORE STREAKS, REFRESH, REQUEST HEALTH ACCESS, HEALTH SETTINGS. FIND MORE STREAKS has a filled background while the other three are outlined — that's the only differentiation. As a new user with an empty dashboard, "REQUEST HEALTH ACCESS" should be the primary call-to-action if access was denied, not FIND MORE STREAKS.

**Fix:** Make the most contextually relevant action visually primary. If Health access is denied, make "REQUEST HEALTH ACCESS" the prominent button.

### 2.9 Hero Card Min Height Is Wasteful on Large Phones
The hero card has a fixed `minHeight: 196`. On an iPhone 15 Pro Max, this leaves significant dead space inside the card. On an iPhone SE, it might be tight. The hero is your crown jewel — it should fit its content, not enforce arbitrary height.

**Fix:** Remove `minHeight` or make it proportional to screen height. Let the content drive the layout.

### 2.10 Coachmark Tutorial Has Fragile Timing
The tutorial fires after a 250ms delay to wait for SwiftUI anchor preferences to settle. If the app is slow to render (older device, cold launch), the tutorial might anchor to the wrong positions or not fire at all. The "gear" tutorial step scrolls to the top bar, but the gear might already be scrolled off-screen.

**Fix:** Use `.onPreferenceChange` to detect when all anchors are ready, then fire the tutorial immediately. Make the gear step always accessible (see 2.4).

---

## 3. Streak Detail View

### 3.1 No Visual History for Hour-Window Streaks
If I have a "morning steps" streak (2,000 steps before 10 AM), tapping the hero card takes me to the detail view — where I see NO calendar heatmap at all. Instead, I get a static text block explaining time-of-day streaks. I can't see any history. I can't see which days I hit my morning goal and which days I didn't. This is a significant gap — these streaks arguably need history *more* than whole-day streaks because the constraint is tighter.

**Fix:** Show the heatmap for hour-window streaks too. Use a different color encoding — e.g., green = met window, amber = met overall goal but not window, red = missed both, gray = no data.

### 3.2 Heatmap Cells Can't Be Tapped
I can see I missed a day (dim cell), but I can't tap it to see what happened. Did I get 9,500 steps (just under 10k)? Or did I get 200 steps (sick in bed)? The data is available but unreachable. The heatmap tells me *whether* I met the goal, not *how close* I was.

**Fix:** Make cells tappable. Show a popover or sheet with the actual value + date when tapped.

### 3.3 Heatmap Is Binary — No Gradient
A day where I crushed 25,000 steps looks identical to a day where I barely scraped 10,001. There's no intensity encoding at all. The `value` field exists in the data model but is never surfaced in the UI. Over time, this makes the heatmap less useful — I want to see trends, not just pass/fail.

**Fix:** Use color intensity (darker/brighter shade of the accent color) to encode how far above the threshold each day was. Cap at 2× threshold for maximum saturation.

### 3.4 1-Year Heatmap Is Near-Invisible
The heatmap is locked to 140pt height. At the 1-year range with 365 days, each cell becomes about 2.5pt wide — essentially a dot. The `max(2, cellWidth)` guard prevents zero-width, but the cells are too small to be meaningful. I can see color but not individual days.

**Fix:** Allow the heatmap to scroll horizontally at the 6-month and 1-year ranges, or increase the height significantly at those ranges.

### 3.5 Recalibrate Has No Loading State
When I tap "Recalibrate," I get a confirmation alert, then a text message "Recalibrating from Apple Health..." — but the button remains tappable, and there's no spinner. If I tap it again during the recalibration, nothing happens (luckily there's a guard), but I don't know the app heard me.

**Fix:** Show a `ProgressView()` spinner during recalibration. Disable the button while recalibrating.

### 3.6 Action Messages Are Scrolled Off-Screen
When I tap "Make Primary," a confirmation message appears at the very top of the scroll view: "Primary streak updated." If I've scrolled down to look at the heatmap, I'll never see this message. It's invisible feedback.

**Fix:** Show action confirmations as a toast/overlay at the bottom of the screen, or use a brief haptic + a temporary banner pinned to the top.

### 3.7 ~200 Lines of Dead Code
The detail view has entire components defined but never wired up: `todayCard`, `makePrimaryCard`, `untrackCard`, `recalibrateCard`, `weekdayHistogram`, `thresholdLadder`. These are fully implemented but unreachable from `body`. This suggests features were planned and possibly built, then abandoned or replaced by `quickActionsCard` without cleanup. It adds maintenance burden and confuses anyone reading the code.

**Fix:** Delete the dead code or wire up the weekday histogram and threshold ladder — they'd be genuinely useful (showing which weekdays are hardest for you, and what thresholds you've tried).

---

## 4. Premium / Paywall Experience

### 4.1 "You Have Grace Days Banked — But You Can't Use Them"
This is by design (the "accrue but can't spend" upsell strategy), but as a user it feels like a bait-and-switch. I've been using the app for 90 days, I've earned 3 Grace Days (the app told me I was earning them!), and now my 47-day steps streak breaks because I missed one day. The app says "YOU HAVE 3 GRACE DAYS BANKED. Unlock Pro to use one."

Wait — I *earned* these. Now you're telling me they're locked behind a paywall? This feels like the app tricked me into accruing currency I can't actually use.

**Mitigation:** The "LOCKED" chip in Settings and the upsell panel in the broken-streak flow do explain this, but the explanation comes *after* the user has already invested time earning them. A first-time user should be told *before* they start earning that Grace Days require Pro to spend. Currently, the "awardGraceDays" function runs silently for free users with zero messaging about the restriction.

**Fix:** When the first Grace Day is awarded to a free user, show a brief explainer: "You earned a Grace Day! Grace Days are banked automatically. Upgrade to Pro to spend them on streak preservation." Not a full paywall — just a one-time heads-up.

### 4.2 Paywall Can Show an Endless Spinner
If `StoreKitService.loadProducts()` fails (network issue, App Store downtime, sandbox problem), `lastError` is set but the paywall doesn't check for it when `products.isEmpty`. The user sees "LOADING PRICES…" with a spinner — forever. No retry button, no error message, no way to dismiss. The only escape is swiping down to close the sheet.

**Fix:** After a timeout (e.g., 10 seconds), show "Couldn't load prices. Check your connection and try again." with a "RETRY" button and a "NOT NOW" dismiss.

### 4.3 Three Sheet Levels Deep for Custom Streaks
To create a second custom streak as a free user: Dashboard → Settings (sheet) → Tracked Streaks / Streak Picker (sheet) → BUILD YOUR OWN (triggers ProPaywall, another sheet). That's three sheets stacked on top of each other. On iOS, this feels claustrophobic — each sheet gets progressively shorter, and the visual stacking makes the app feel like it's burying me.

**Fix:** For the Pro upsell path specifically, dismiss the intermediate sheet before presenting the paywall, or use a full-screen cover instead of a sheet for the paywall.

### 4.4 Yearly Trial Duration Mismatch
The taste file notes the yearly subscription has a 7-day free trial configured as `P1D` with 7 periods instead of `P1W` with 1 period. While functionally equivalent, some App Review reviewers prefer the canonical format. Not a user-facing issue, but worth noting.

### 4.5 "Manage Subscription" Only Appears Under Specific Conditions
The "Manage Subscription" link in Settings only appears when the user is Pro AND has recent preservation entries. If I'm Pro and want to cancel, but I haven't had a streak preserved recently, the link is simply absent. I'd have to dig into iOS Settings → Apple ID → Subscriptions manually, which I might not know how to do.

**Fix:** Always show "Manage Subscription" when `isPro == true`, regardless of preservation history.

---

## 5. Settings & Customization

### 5.1 Discovery Window Is Buried
The "Discovery Window" setting (7/30/90/180/365 days of history to analyze) only appears inside the Intensity section as a small picker row. It's arguably one of the most powerful tuning knobs in the app — changing it from 30 to 90 days can significantly change your goal thresholds — but it's easy to miss entirely.

**Fix:** Give it its own labeled section, or at least make the picker more prominent within the Intensity section.

### 5.2 Changing Discovery Window Doesn't Explain the Impact
When I change the discovery window from 30 to 90 days, a prompt asks "Recalibrate goals with new window?" — but there's no explanation of what "recalibrate" means in this context. Will my current streaks break? Will my thresholds change? The word "recalibrate" is jargon.

**Fix:** Add a sentence: "This may change your daily goals based on your longer history. Your current streak count will stay the same unless a goal becomes harder."

### 5.3 Notification Time Picker Is Awkward
The time picker is a standard iOS `DatePicker` set to `.hourAndMinute`. It works, but it takes up a lot of vertical space. On smaller phones, this pushes other settings down. Also, the picker's default time of 7:00 PM isn't shown anywhere before I enable notifications — I don't know what time the reminder will fire until I turn it on.

**Fix:** Show the default time before enabling: "Daily reminder at 7:00 PM · OFF". Use a compact picker (wheel style or a custom time selector).

### 5.4 "Metrics Tracked" List Is Flat
Eleven toggles in a flat list with no grouping. Steps, Exercise, Stand, Active Energy, and Workouts are the core Apple Activity ring metrics — they should be visually distinct from Sleep, Mindfulness, Flights Climbed, etc. As a user, I might not know what "Intensity" or "Cardio Minutes" even means in the context of my data.

**Fix:** Group into "Activity Ring" and "Additional Health Metrics." Add brief descriptions under less common metrics.

### 5.5 No Search or Filter in Streak Picker
The Streak Picker (for selecting which streaks to track) shows all discovered streaks in a flat list. If I have 25+ discovered streaks, finding a specific one (e.g., "Running workouts — 3 per week") requires scrolling and reading carefully. There's no search, no filter by metric type, no sorting beyond the default (core metrics first, then alphabetically).

**Fix:** Add a search field and/or metric filter chips at the top of the picker.

### 5.6 Planned Freezes Are Easy to Miss
Planned Freezes (for vacations, sick days) are a great feature — but they're buried near the bottom of Settings. A user going on vacation Monday probably won't think to dig through Settings to find them. They're also not mentioned in the dashboard tutorial or any onboarding tip.

**Fix:** Add a "PLANNED FREEZE" row to the dashboard (below the at-risk banner, perhaps) when the user has upcoming freezes. Mention freezes in the coachmark tutorial or during onboarding tips.

---

## 6. Watch App

### 6.1 Watch Complication Can Be Stale for Hours
The watch complication timeline only has two entries: now and midnight. It doesn't refresh mid-day unless the user opens the watch app, which triggers a sync. If I check my complication at 3 PM, it might show whatever data was synced at 8 AM. My step count has changed dramatically, but the complication shows stale numbers with no indication they're old.

**Fix:** Add more timeline entries throughout the day (e.g., every 2 hours), or use `WidgetCenter.shared.reloadAllTimelines()` from the iPhone side when HealthKit data changes significantly.

### 6.2 All Watch Sync Failures Are Silent
If the watch can't reach the iPhone (Bluetooth off, phone out of range, airplane mode), the watch just shows stale data or an empty state. There's no "⚠️ Can't sync" indicator, no retry button, no explanation. The user sees potentially hours-old data and has no way to know it's not current — unless they notice the timestamp in the app itself.

**Fix:** Show a subtle orange/yellow indicator when the last sync was > 1 hour ago: "⚠️ Last updated 3h ago." Add a "TAP TO RETRY" affordance.

### 6.3 No Complication Configuration
The watch complication always shows the hero streak — whatever the engine decided is primary. I can't choose to show my Exercise streak instead of Steps on my watch face. If I primarily care about my running streak, I'm stuck looking at whatever the engine picked.

**Fix:** Use `AppIntentConfiguration` instead of `StaticConfiguration` so users can choose which streak to display on their watch face.

### 6.4 Background Refresh Is Unreliable
The watch schedules a background refresh every 30 minutes, but watchOS budgets these aggressively. If the user doesn't open the watch app regularly, background refreshes might not fire for hours. The app depends on these refreshes to pull new data from the iPhone.

**Fix:** This is mostly a platform limitation. Mitigate by increasing the number of complication timeline entries (see 6.1) so at least the complication stays somewhat fresh without background refresh.

---

## 7. Widgets

### 7.1 Widget Always Shows the Hero Streak
Same issue as the watch complication — the home screen widget has no configuration. It always shows the hero streak. I can't choose to display a specific metric on my home screen. The widget description says "Your hottest streak, at a glance," but I might want my running streak specifically.

**Fix:** Use `AppIntentConfiguration` to let users pick which streak to display in the widget.

### 7.2 No Widget for Multiple Streaks in Small Size
The small widget only shows the hero. The medium widget shows hero + up to 3 badges. There's no way to see, say, just my top 3 streaks without the hero dominating half the medium widget. A user who doesn't care about the hero but wants to track several specific badges has no good option.

**Fix:** Offer a "compact badge grid" small widget option, or let users configure what the small widget shows.

### 7.3 Lock Screen Widgets Are Basic
The lock screen widgets (inline, circular, rectangular) are clean but minimalist — just the current value + goal + progress. The circular widget shows a gauge ring, which is the best of the three. The inline widget ("🔥 8,200 / 10,000 steps") is useful but lacks the streak count (how many days?). The rectangular widget includes the streak count, which is better.

**Fix:** Add streak count to the inline widget: "🔥 8,200/10k steps · 47 days." It's a text widget — use the space.

---

## 8. Notifications

### 8.1 Notifications Don't Appear When App Is Open
There's no `UNUserNotificationCenterDelegate` implementation. This means if the app is foregrounded when a notification fires, the notification is silently swallowed. If I'm browsing my streaks at 7:00 PM when my daily reminder fires, I'll never see it. The broken streak notification (1-second delay) is especially vulnerable to this — it almost always fires while the app is still in the foreground after a refresh.

**Fix:** Set a `UNUserNotificationCenterDelegate` that calls `completionHandler([.banner, .sound, .badge])` in `userNotificationCenter(_:willPresent:withCompletionHandler:)`.

### 8.2 Broken Streak Notification Uses a 1-Second Trigger
The "streak ended" notification uses `UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)`. A 1-second delay is unnecessarily fragile — if the app is still foregrounded (which it almost always is, since the break is detected during a refresh the user initiated), the notification is dropped (see 8.1). The user might never know their streak broke until they notice the broken streak banner on the dashboard.

**Fix:** Use a longer delay (5–10 seconds) or a calendar-based trigger. More importantly, fix 8.1 first — that's the root cause.

### 8.3 No Grace Day Preservation Notification
When a Grace Day is consumed (Pro users only), the streak is silently preserved. The user never gets a notification: "Your steps streak was saved! 1 Grace Day used (2 remaining)." This is arguably the most valuable Pro feature, and it happens invisibly. The user might not even realize the Grace Day worked until they check their streak count.

**Fix:** Send a notification when a Grace Day is consumed, celebrating the save and showing remaining balance.

### 8.4 "At-Risk Reminder" Only Fires for Streaks ≥ 2 Days
Day-1 streaks don't trigger reminders. This is intentional (a one-day streak isn't meaningfully "at risk"), but if someone starts a new streak and wants to build the habit, a day-2 reminder might be appreciated.

**Fix:** Optionally allow reminders for day-1 streaks, or add a separate "build the habit" notification type for new streaks.

---

## 9. Custom Streaks

### 9.1 No Preview or Viability Check
When I create a custom streak (e.g., "50,000 steps daily"), I get zero feedback on whether that's achievable. The ADD button lights up as long as the number is > 0. I could create a 999,999-steps streak and the app would happily create it, showing `current: 0` forever. There's no "Based on your history, you'd have hit this goal on 12% of days" viability check.

**Fix:** After the user enters a threshold, run a quick check against their recent history and show a viability estimate: "You'd have met this goal on 18 of your last 30 days (60%)."

### 9.2 Can't Edit Anything but the Threshold
After creating a custom streak, the edit sheet only exposes the threshold value. I can't change the metric, the workout type, the measure (count/minutes/miles), or the hour window. If I made a "Running — Count" streak but meant "Running — Minutes," I have to disable the metric entirely and create a new one. And I can't delete the wrong one.

**Fix:** Full edit capability for custom streaks, or at minimum, allow changing the workout type, measure, and hour window.

### 9.3 No Way to Delete a Custom Streak
Once created, a custom streak lives forever. The only way to remove it from the dashboard is to disable the metric entirely in Settings — which also hides all other streaks of that metric type. There's no trash icon, no swipe-to-delete, no delete button anywhere in the UI.

**Fix:** Add a delete option to the custom streak edit sheet, or a swipe-to-delete gesture in the streak picker list.

### 9.4 Stepper in Edit Sheet Is Unusable
The threshold edit sheet has a `Stepper` with 100-step increments (for steps). To go from 3,000 to 12,000 steps, I have to tap the "+" button 90 times. The stepper labels are hidden, making it a pair of tiny +/- buttons. There's no way to type a value — the text field is non-editable in this sheet (it's editable in the builder but not the editor).

**Fix:** Make the text field editable in the edit sheet. Keep the stepper as a secondary control, or replace it with a slider.

### 9.5 "Hour Window Only for Steps" Is Unexplained
The TIME WINDOW toggle only appears when `metric == .steps`. A user wanting "morning mindfulness" or "evening exercise" sees nothing and doesn't know why. There's no explanation that this feature is limited to steps, and no indication of whether it might be expanded.

**Fix:** Add a brief note: "Hour windows are currently available for steps. More metrics coming soon." Or better, implement hour windows for all metrics.

### 9.6 Duplicate Custom Streaks Are Allowed
I can create two custom streaks with identical metric + threshold + parameters. They'd appear as separate entries, track identically, and clutter the dashboard. There's no duplicate detection at creation time.

**Fix:** Check for duplicates before saving: "You already have a streak for this metric with this threshold. Create anyway?"

### 9.7 Free Tier Limit Is Well-Signaled but Could Be Earlier
The "1 custom streak (free) / unlimited (Pro)" model is clearly communicated with the "LOCKED" chip and the "— PRO" label on the button. However, the user only discovers this limit *after* they've already created one custom streak and try to create a second. A first-time custom-streak builder has no idea there's a limit until they hit it.

**Fix:** On the custom streak builder sheet, show a subtle footer for free users: "1 of 1 custom streak available on the free plan. Upgrade to Pro for unlimited." This sets expectations before the user invests time building their first custom streak.

---

## 10. Error Handling & Edge Cases

### 10.1 Silent HealthKit Fetch Failures
If `StreakStore.load()` fails to fetch fresh HealthKit data, it silently falls back to cached data. The user sees no error, no banner, no indication that the refresh failed — the dashboard just continues showing whatever was cached. The timestamp doesn't update. The user might think the app refreshed successfully but nothing changed.

**Fix:** Show a subtle banner: "Couldn't refresh from Apple Health — showing cached data." with a retry button.

### 10.2 StoreKit Product Load Failure — Endless Spinner
As noted in 4.2: if product loading fails, the paywall shows a spinner forever with no error state and no way to retry or dismiss beyond swiping.

### 10.3 All Watch Connectivity Failures Are Invisible
As noted in 6.2: the watch gives zero indication when sync fails. Stale data is shown as if it's current.

### 10.4 Final DataService Fallback Uses `try!` (Can Crash)
If all three data store fallbacks fail (corruption → in-memory → in-memory2), the fourth fallback uses `try!` which crashes the app. This is an extreme edge case (in-memory ModelContainer creation should always succeed), but a crash is the worst possible outcome.

**Fix:** Replace `try!` with a graceful shutdown — show an alert: "Something went wrong. Please restart the app." — then exit cleanly.

### 10.5 No Foreground Notification Delegate
As noted in 8.1: notifications are invisible when the app is open.

### 10.6 Data Maybe Revoked Detection Is Clever but Brittle
The `dataMaybeRevoked` heuristic (fresh steps == 0 but cache had ≥ 5,000) is clever — it detects HealthKit permission revocation indirectly. But it can false-positive: if the user genuinely had zero steps because they left their phone at home all morning, the app might show the scary "NO RECENT DATA" banner unnecessarily.

**Fix:** Check more than one metric (e.g., steps AND exercise minutes AND energy) before flagging as revoked. Or add a cooldown so the banner doesn't appear on the first zero-data refresh.

---

## 11. General Polish & Consistency

### 11.1 Typography Scaling Is Inconsistent
Different text elements use different `minimumScaleFactor` values ranging from 0.45 to 0.75. The hero value can shrink to 45% of its original size while the unit label stays at 70%. This creates a visual hierarchy where the number becomes disproportionately small compared to its label. At extreme shrinkage on a small phone (iPhone SE), text can become genuinely illegible.

**Fix:** Use a consistent minimum scale factor across all text in a given component, or use `.scaledToFit()` with a single factor. Consider using dynamic type with a custom size range.

### 11.2 Shadow/Glow Clipping at Tight Spacing
The badge grid uses 8px spacing with `retroGlow` shadows that have a 14px radius. Adjacent badges may have shadow overlap at this spacing. On dark backgrounds, the glow bleed between cards could look muddy rather than crisp.

**Fix:** Increase grid spacing to 12px, or reduce the glow radius to 10px.

### 11.3 Progress Percentage at 0% Is Misleading
If I've taken exactly 0 steps today (just woke up, haven't moved), the progress text shows "0%". If I've taken 42 steps (0.4% of a 10,000-step goal), it also shows "0%" because of the `Int(min(1, progress) * 100)` rounding. A user who checks the app after walking to the kitchen sees "0%" and thinks nothing registered.

**Fix:** Show "<1%" for values between 0 and 1%, or show the raw value ("42 / 10,000 steps" instead of "0%").

### 11.4 Weekly Cadence Text Can Be Verbose
For a 52-week exercise streak, the badge shows "52 weeks streak" — long text in a small meta font. Combined with the metric name and goal, the badge card has a lot of text competing for limited space.

**Fix:** Abbreviate to "52w" in the badge card, keeping the full "52 weeks" for the detail view.

### 11.5 No Haptic Feedback
The app uses zero haptic feedback anywhere. No haptic on pull-to-refresh (which doesn't exist yet — see 2.1), no haptic on streak broken, no haptic on Grace Day consumed, no haptic on "Make Primary" or "Untrack" confirmations. Haptics are a cheap way to make an app feel responsive and premium.

**Fix:** Add `.sensoryFeedback(.success, trigger: ...)` to streak completions, Grace Day consumption, and primary actions. Add `.sensoryFeedback(.warning, trigger: ...)` to streak breaks.

### 11.6 No Dark Mode Toggle During Onboarding
The appearance setting (Light/Dark/System) is only accessible from Settings after onboarding. If I start the app at night in dark mode but prefer light mode, I have to complete onboarding first, then dig into Settings.

**Fix:** Add a small appearance toggle to the onboarding intro screen, or respect the system setting during onboarding (which you already do — but no way to override during onboarding).

---

## Severity Summary

| # | Issue | Severity |
|---|---|---|
| 2.1 | No pull-to-refresh | 🔴 High |
| 2.2 | Dashboard vanishes during refresh | 🔴 High |
| 8.1 | Notifications invisible when app is open | 🔴 High |
| 10.1 | Silent HealthKit fetch failures | 🔴 High |
| 4.1 | Grace Days feel like bait-and-switch | 🟡 Medium |
| 2.4 | Settings gear scrolls away | 🟡 Medium |
| 3.1 | No heatmap for hour-window streaks | 🟡 Medium |
| 6.1 | Watch complication can be stale for hours | 🟡 Medium |
| 9.2 | Can't edit custom streak params | 🟡 Medium |
| 9.3 | No way to delete custom streaks | 🟡 Medium |
| 10.2 | Paywall endless spinner on product load fail | 🟡 Medium |
| 2.3 | Timestamp doesn't update live | 🟠 Low |
| 2.5 | Visual misalignment (16px vs 6px) | 🟠 Low |
| 2.6 | Broken streak banner lacks tap affordance | 🟠 Low |
| 3.3 | Binary heatmap (no gradient) | 🟠 Low |
| 3.6 | Action messages scrolled off-screen | 🟠 Low |
| 3.7 | ~200 lines of dead code | 🟠 Low |
| 4.5 | "Manage Subscription" conditionally hidden | 🟠 Low |
| 5.6 | Planned Freezes hard to discover | 🟠 Low |
| 7.1 | Widget always shows hero streak | 🟠 Low |
| 8.3 | No Grace Day preservation notification | 🟠 Low |
| 9.1 | No custom streak viability preview | 🟠 Low |
| 9.4 | Stepper in edit sheet is unusable | 🟠 Low |
| 11.5 | No haptic feedback anywhere | 🟠 Low |
