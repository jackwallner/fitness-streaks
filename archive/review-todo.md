# Fitness Streaks - Exhaustive Human Review Checklist

## Overview
Review every feature as a real human user would experience it. Focus on: **Does it work?** and **Is data consistent across all surfaces?**

---

## 1. Onboarding Flow

### 1.1 First Launch Experience
- [ ] App opens to onboarding (clean install)
- [ ] Welcome screen shows: app name, tagline, privacy note
- [ ] Flame icon pulses/glows as expected
- [ ] "CONNECT APPLE HEALTH" button is prominent and tappable
- [ ] Privacy policy link opens in browser

### 1.2 Health Authorization
- [ ] Tapping "CONNECT APPLE HEALTH" triggers system permission sheet
- [ ] Permission sheet lists all expected data types:
  - Steps, Exercise Time, Stand Hours, Active Energy
  - Workouts, Mindful Minutes, Sleep Analysis
  - Distance, Flights Climbed, Heart Rate
- [ ] If user denies: appropriate error message shown
- [ ] If user grants: progresses to intensity selection
- [ ] No crash if HealthKit is unavailable (iPad simulator)

### 1.3 Intensity Selection
- [ ] Three options clearly presented: Sustained / Challenging / Life Changing
- [ ] Each shows label + tagline explaining what it means
- [ ] Selection is saved and respected in discovery
- [ ] Can proceed to streak discovery after selection

### 1.4 Discovery Loading
- [ ] Loading screen shows animated flame
- [ ] Tips rotate every 3.5 seconds
- [ ] Progress bar advances during loading
- [ ] Real data is being fetched from HealthKit (not fake delay)

### 1.5 Streak Selection
- [ ] Discovered streaks presented in scrollable list
- [ ] Each streak shows: icon, name, threshold, preview of current streak length
- [ ] Multi-select works (checkboxes or highlight)
- [ ] Can select 0 streaks → "empty" state handled gracefully
- [ ] "START TRACKING" button enabled when ≥1 selected
- [ ] Selected streaks appear on dashboard after completion

### 1.6 Empty Discovery State
- [ ] If no streaks discovered: helpful empty state shown
- [ ] Message explains why (not enough Health data)
- [ ] Suggests actions: add workouts, wear Apple Watch, etc.

---

## 2. Main Dashboard

### 2.1 Layout & Visuals
- [ ] Pixel-art retro theme consistent throughout
- [ ] Top bar: app name, last updated timestamp, refresh button, settings button
- [ ] "STREAK FINDER" header visible
- [ ] "from apple health" or relative timestamp shown
- [ ] Pull-to-refresh works (or refresh button works)

### 2.2 Hero Streak Card
- [ ] Largest/most prominent card shows primary streak
- [ ] Displays: streak count (e.g., "42 DAYS"), metric icon, metric name, threshold
- [ ] Progress indicator for today's completion
- [ ] Color matches metric (steps=purple, exercise=green, etc.)
- [ ] Tapping hero opens detail view

### 2.3 Badge Grid (Secondary Streaks)
- [ ] Shows count of active streaks: "Other Streaks · 3 Active"
- [ ] 2-column grid layout
- [ ] Each badge shows: icon, metric name, streak count
- [ ] Color-coded by metric type
- [ ] Tapping any badge opens its detail view
- [ ] Grid scrolls if more than ~6 streaks

### 2.4 At-Risk Banner
- [ ] Appears after notification time if hero streak not completed today
- [ ] Shows: "AT RISK" label, metric name, current progress
- [ ] Urgent but not alarming styling
- [ ] Disappears once today's goal is met

### 2.5 Broken Streak Banners
- [ ] Appears when a tracked streak was broken
- [ ] Shows: metric name, final streak length, "STREAK ENDED"
- [ ] Provides actions: RESTART, PICK NEW, DISMISS
- [ ] Only shows for streaks that were being tracked (not hidden)
- [ ] Auto-dismisses after 48 hours

### 2.6 Health Access Revoked Banner
- [ ] Appears if HealthKit access lost
- [ ] Message: "NO RECENT DATA - Apple Health may have revoked access"
- [ ] Tapping opens Health app or Settings
- [ ] Disappears when access is restored

### 2.7 Empty States
- [ ] Loading state: spinner/animation shown while fetching
- [ ] No streaks: friendly empty state with setup guidance

---

## 3. Streak Detail View

### 3.1 Header Information
- [ ] Large streak count displayed prominently
- [ ] "DAYS" or "WEEKS" label matches cadence
- [ ] Metric icon and name shown
- [ ] Threshold clearly stated: "10,000 steps every day"

### 3.2 Progress Section
- [ ] Today's progress bar/graph visible
- [ ] Current value vs goal: "6,243 / 10,000 steps"
- [ ] Percentage or visual completion indicator
- [ ] Updates in real-time (or on refresh)

### 3.3 Calendar View
- [ ] Monthly calendar shows streak history
- [ ] Completed days highlighted in metric color
- [ ] Missed days clearly indicated
- [ ] Today marked distinctly
- [ ] Can scroll to previous months
- [ ] Grace day usage indicated (if applicable)

### 3.4 Statistics
- [ ] Best streak length shown
- [ ] Current streak length shown
- [ ] Start date of current streak
- [ ] Historical completion rate (if available)

### 3.5 Actions
- [ ] "HIDE STREAK" removes from dashboard but keeps data
- [ ] Hidden streaks can be restored from Settings
- [ ] Back button returns to dashboard

---

## 4. Settings

### 4.1 Settings Menu Structure
- [ ] Opens from dashboard gear icon
- [ ] Modal sheet presentation
- [ ] Sections clearly organized:
  - Tracked Streaks
  - Discovery Intensity
  - Hidden Metrics
  - Notifications
  - Appearance
  - Pro Features
  - Help & Support

### 4.2 Tracked Streaks Management
- [ ] List shows all currently tracked streaks
- [ ] Can reorder streaks (drag handle)
- [ ] Swipe to hide/delete
- [ ] "+ ADD STREAK" opens discovery picker
- [ ] Changes reflect immediately on dashboard

### 4.3 Discovery Intensity
- [ ] Current selection highlighted
- [ ] Can change between: Sustained / Challenging / Life Changing
- [ ] New discovery runs when changed
- [ ] Previously hidden streaks may reappear if they fit new intensity

### 4.4 Hidden Metrics
- [ ] List of metrics user has hidden (not per-streak)
- [ ] Toggle to unhide
- [ ] Unhiding restores all streaks of that metric type
- [ ] Metric-level hiding (not individual streak hiding)

### 4.5 Notifications
- [ ] Toggle for "Daily Reminders"
- [ ] Time picker for reminder (hour + minute)
- [ ] If denied: shows how to enable in Settings.app
- [ ] Reminder only fires if streak at risk
- [ ] Reminder time can be changed

### 4.6 Appearance
- [ ] Theme selector: System / Light / Dark
- [ ] App responds immediately to change
- [ ] Widgets reflect appearance setting
- [ ] All screens respect appearance

### 4.7 Pro Features (StoreKit)
- [ ] "Upgrade to Pro" visible for free users
- [ ] Pro features list shown:
  - Grace days (bank and spend)
  - Unlimited streaks
  - Advanced widgets
  - Export data
- [ ] Restore Purchases button
- [ ] Subscription/pricing clearly displayed
- [ ] Purchase flow works end-to-end

### 4.8 Grace Days (Pro)
- [ ] Shows current banked grace days count
- [ ] Shows next tier: "Bank 1 more at 60 days"
- [ ] Grace days accrue automatically (30-day tiers)
- [ ] Grace days can be spent to save broken streak
- [ ] Visual indicator when grace day used

### 4.9 Help & Support
- [ ] Help/FAQ option
- [ ] Contact support email link
- [ ] Privacy policy link
- [ ] Terms of service link

---

## 5. Streak Discovery (Post-Onboarding)

### 5.1 "Find More" Button
- [ ] Button visible on dashboard
- [ ] Opens streak picker sheet
- [ ] Lists available streaks not currently tracked

### 5.2 Streak Picker Sheet
- [ ] All discoverable streaks listed
- [ ] Each shows: metric icon, name, threshold, preview streak length
- [ ] Multi-select interface
- [ ] "ADD SELECTED" button
- [ ] Cancel button dismisses without changes

### 5.3 Discovery Logic
- [ ] Respects intensity setting (80%/65%/50% thresholds)
- [ ] Suggests achievable but meaningful streaks
- [ ] Per-workout-type streaks discoverable
- [ ] Hour-window streaks discoverable (early steps)

---

## 6. Widgets

### 6.1 Home Screen Widget (iOS)
- [ ] Small widget: shows hero streak, count, progress
- [ ] Medium widget: hero + up to 3 secondary streaks
- [ ] Widget updates when app updates data
- [ ] Tap opens app to dashboard
- [ ] Placeholder shown when no streaks configured

### 6.2 Lock Screen Widgets (iOS 16+)
- [ ] Inline widget: one-line hero streak status
- [ ] Circular widget: gauge with progress ring
- [ ] Rectangular widget: icon + value + progress
- [ ] Updates at midnight to reset "today" state
- [ ] Updates when streaks change

### 6.3 Widget Data Consistency
- [ ] Widget streak count matches app dashboard
- [ ] Widget progress matches app progress
- [ ] Widget metric name matches app
- [ ] Widget updates within 5 minutes of app update
- [ ] No stale data displayed

---

## 7. Apple Watch

### 7.1 Watch App
- [ ] App launches on watch
- [ ] Shows hero streak prominently
- [ ] Lists secondary streaks (scrollable)
- [ ] Shows today's progress for each
- [ ] Pull-to-refresh syncs data

### 7.2 Watch Complications
- [ ] Complication available in all families:
  - Graphic Corner
  - Graphic Circular  
  - Modular Small
  - Modular Large
  - Utility Small
  - Utility Large
- [ ] Shows hero streak count
- [ ] Updates regularly
- [ ] Tapping opens watch app

### 7.3 Watch Data Consistency
- [ ] Watch streak count matches iPhone
- [ ] Watch progress matches iPhone
- [ ] Sync happens via WatchConnectivity
- [ ] Works when iPhone is nearby
- [ ] Caches data for offline viewing

---

## 8. Notifications

### 8.1 Daily Reminder
- [ ] Fires at user-selected time
- [ ] Only fires if streak at risk (not completed)
- [ ] Message is personalized: "Keep the 10k steps streak alive - You're at 42 days"
- [ ] Includes deadline: "before midnight" or "by 9am" for hour-window streaks
- [ ] Sound plays (respects Do Not Disturb)

### 8.2 Streak Broken Notification
- [ ] Immediate notification when streak breaks
- [ ] Shows: metric name, final streak length
- [ ] Deep link opens app to broken streak sheet
- [ ] Can restart or pick new streak from notification

### 8.3 Notification Permission Handling
- [ ] Request only from explicit user toggle (not on launch)
- [ ] If denied: shows instructions to enable in Settings
- [ ] Toggle reflects actual permission state
- [ ] No crash if notifications unavailable

---

## 9. HealthKit Integration

### 9.1 Data Reading
- [ ] Reads steps from HealthKit accurately
- [ ] Reads exercise minutes accurately
- [ ] Reads stand hours accurately
- [ ] Reads active energy accurately
- [ ] Reads workout data (count + duration + distance)
- [ ] Reads mindful minutes
- [ ] Reads sleep hours (handles overnight samples correctly)
- [ ] Reads distance (walking/running)
- [ ] Reads flights climbed
- [ ] Reads heart rate for cardio minutes

### 9.2 Data Freshness
- [ ] Pull-to-refresh fetches latest HealthKit data
- [ ] App background refresh updates data
- [ ] Last updated timestamp accurate
- [ ] No stale data shown after HealthKit updates

### 9.3 Permission Handling
- [ ] Graceful degradation if permission denied for specific type
- [ ] Revoked access detected and banner shown
- [ ] Re-requesting permissions works
- [ ] No crash with partial permissions

### 9.4 Edge Cases
- [ ] Handles days with no data (counts as missed)
- [ ] Handles partial day data correctly
- [ ] Time zone changes handled correctly
- [ ] Daylight saving time transitions handled
- [ ] Sleep samples crossing midnight credited to correct day

---

## 10. Streak Engine Logic

### 10.1 Daily Streak Calculation
- [ ] Streak increments when daily goal met
- [ ] Streak breaks when daily goal missed
- [ ] Today doesn't break streak until day ends
- [ ] Historical data correctly evaluated
- [ ] First day of streak identified correctly

### 10.2 Weekly Streak Calculation
- [ ] Week defined Monday-Sunday (ISO standard)
- [ ] Weekly streak increments when weekly goal met
- [ ] Partial weeks handled correctly

### 10.3 Hour-Window Streaks (Early Steps)
- [ ] Only counts steps before specified hour
- [ ] Window end time clearly labeled
- [ ] Missed window = missed day for that streak

### 10.4 Per-Workout-Type Streaks
- [ ] Running streak separate from Cycling streak
- [ ] Distance-based goals work (10 miles running)
- [ ] Time-based goals work (30 min yoga)
- [ ] Count-based goals work (any swim session)
- [ ] Correctly aggregates multiple sessions per day

### 10.5 Grace Days (Pro)
- [ ] Grace day spent automatically when streak would break
- [ ] Visual indication grace day was used
- [ ] Streak preserved in display
- [ ] Grace day count decreases
- [ ] Cannot spend grace days without Pro subscription

### 10.6 Broken Streak Detection
- [ ] Break detected day after missed goal
- [ ] Broken streak banner appears
- [ ] Streak removed from active badges
- [ ] Historical record preserved
- [ ] Can restart same streak or pick new

---

## 11. Data Consistency Across Surfaces

### 11.1 Dashboard ↔ Detail View
- [ ] Streak count matches
- [ ] Today's progress matches
- [ ] Metric name matches
- [ ] Threshold matches
- [ ] Color coding matches

### 11.2 App ↔ Widget
- [ ] Hero streak is same in both
- [ ] Streak count identical
- [ ] Progress percentage identical
- [ ] Metric name/label identical
- [ ] Last update time reflects widget data age

### 11.3 iPhone ↔ Watch
- [ ] Hero streak matches
- [ ] Badge counts match
- [ ] Progress values match
- [ ] Sync completes within 30 seconds

### 11.4 App ↔ Notifications
- [ ] Streak count in notification matches app
- [ ] Metric name in notification matches app
- [ ] "At risk" status consistent

### 11.5 Settings ↔ Dashboard
- [ ] Hidden metrics don't appear on dashboard
- [ ] Reordered streaks reflect in dashboard order
- [ ] Newly added streaks appear immediately

---

## 12. Visual Design & UX

### 12.1 Theme Consistency
- [ ] Retro pixel aesthetic throughout
- [ ] Monospace font used for numbers
- [ ] Color palette consistent (12 metric colors)
- [ ] Card/raised surfaces consistent
- [ ] Borders/strokes consistent (2px style)

### 12.2 Accessibility
- [ ] Dynamic Type supported (text scales)
- [ ] VoiceOver labels on all interactive elements
- [ ] Sufficient color contrast
- [ ] Interactive elements minimum 44pt
- [ ] Reduced Motion respected

### 12.3 Animations
- [ ] Loading animations smooth
- [ ] Page transitions appropriate
- [ ] Flame pulse on onboarding
- [ ] Progress animations smooth
- [ ] No jarring or excessive motion

### 12.4 Error States
- [ ] Network/HealthKit errors show friendly message
- [ ] Retry actions available
- [ ] No technical error codes exposed
- [ ] Empty states are helpful, not blank

---

## 13. Performance

### 13.1 Launch Time
- [ ] Cold launch < 3 seconds
- [ ] Dashboard visible quickly
- [ ] Data loads progressively (not blocking UI)

### 13.2 HealthKit Queries
- [ ] Queries complete in < 5 seconds
- [ ] Progress shown during long queries
- [ ] Cancel/timeout handled gracefully
- [ ] No duplicate queries fired

### 13.3 Scrolling
- [ ] Dashboard scrolls at 60fps
- [ ] Detail view calendar scrolls smoothly
- [ ] No layout thrashing

---

## 14. Edge Cases & Stress Testing

### 14.1 New User
- [ ] Fresh install flow works
- [ ] No crash with zero HealthKit data
- [ ] Empty states helpful

### 14.2 Power User (Many Streaks)
- [ ] Handles 20+ streaks gracefully
- [ ] Scroll performance acceptable
- [ ] All streaks visible and tappable

### 14.3 Long Streaks
- [ ] Displays streaks > 365 days correctly
- [ ] No integer overflow issues
- [ ] Calendar view handles multi-year history

### 14.4 Pro User Downgrade
- [ ] Grace days stop working (can't spend)
- [ ] Grace days remain visible (upsell)
- [ ] Streaks preserved
- [ ] Limited to free streak count

### 14.5 Interrupted Onboarding
- [ ] Can resume if app killed during onboarding
- [ ] Doesn't force restart from beginning
- [ ] State restored correctly

### 14.6 Background/Foreground
- [ ] Data refreshes when app returns to foreground
- [ ] Widget updates scheduled properly
- [ ] No stale data after long background

---

## Review Notes Section

### Found Issues
| # | Area | Issue | Severity | Status |
|---|------|-------|----------|--------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

### Data Consistency Checks
| Surface A | Surface B | Match? | Notes |
|-----------|-----------|--------|-------|
| Dashboard Hero | Widget | | |
| Dashboard Progress | Detail View | | |
| iPhone Streak Count | Watch | | |
| Notification Text | App Status | | |

### Sign-Off
- [ ] All P0 features verified
- [ ] All P1 features verified  
- [ ] No blocking bugs found
- [ ] Ready for TestFlight release

---

*Last updated: 2026-05-03*
*App Version: Build 74*
