# UX Review & Pain Points: FitnessStreaks

After an exhaustive review of the application's flows, logic, and presentation, here are the core pain points and friction areas a user would experience, broken down by category. 

## 1. Premium & Pro Features (The "Grace Day" System)
The entire Pro offering hinges on "Grace Days," but the current implementation strips control from the user and feels unrewarding in specific edge cases.

* **Silent/Automatic Spending:** Pro users are told the app "silently spends a Grace Day to preserve your streak." If a user has a 200-day step streak and a 4-day yoga streak, and misses both due to illness, does the app spend a Grace Day on the 4-day streak? Does it spend two? Users want granular control over their hard-earned safety nets. Automatic spending will lead to frustration when a Grace Day is wasted on a low-priority streak. Users should be prompted to "Save Streak?" or at least have a toggle to choose which streaks are eligible for automatic saves.
* **Unfair Earning Logic:** Grace Days are awarded solely based on the *Hero* streak (1 every 30 days). If a user's Hero streak is challenging and breaks frequently, but they maintain a 150-day secondary streak, they earn *zero* Grace Days. The earning mechanic should look at the user's longest active streak or aggregate consistency, rather than just the arbitrarily pinned top streak.
* **Low Visibility:** Pro users have no persistent HUD for their banked Grace Days. The count is buried in Settings or only surfaced to free users as an upsell on the `BrokenStreakSheet`. A small counter on the Dashboard would constantly remind Pro users of the value they are getting.

## 2. Dashboard & Daily Friction
* **Time-Gated "At Risk" Warnings:** The red "! AT RISK" banner only appears *after* the user's configured notification time (e.g., 7:00 PM). If a user checks the app at 2:00 PM, they have no visual indicator that they are falling behind. Users should be able to see at-risk streaks earlier in the day to plan their workouts.
* **Buried "Planned Freezes":** If a user is sick or traveling, they must dig into Settings -> Planned Freezes to add a date. Because this is a primary interaction for maintaining streaks during real-life interruptions, it needs to be accessible from the Dashboard or inside the Streak Detail view.
* **Tedious Reordering:** There is no drag-and-drop functionality on the dashboard. To reorder streaks, the user must tap into a streak and press "Make Primary," which only moves it to the top. Full customization of the dashboard layout is missing.

## 3. Streak Detail View Anxiety
* **"Recalibrate" is Punishing:** The Recalibrate feature explicitly warns the user: *"If the new goal is higher than your recent activity, your streak may break."* This creates massive anxiety. Users will actively avoid engaging with this feature out of fear. Recalibration should either only apply the new threshold *moving forward* (grandfathering past days) or clearly preview the new threshold before any destructive action is taken.

## 4. Typography & Onboarding
* **ALL CAPS Legibility:** The retro aesthetic relies heavily on pixel and mono fonts presented entirely in uppercase. While fine for short labels and numbers, it severely damages legibility for paragraph text. The Paywall descriptions, Onboarding tips, and Settings explanations are difficult to read and parse quickly.
* **Onboarding Flow Rushing:** The onboarding screen shows cycling tips while HealthKit discovery runs. If the user has a fast device and small HealthKit history, the discovery might finish in 0.5 seconds, causing the tips to flash unreadably fast before transitioning to the next screen. 
* **Premature Intensity Choice:** Asking the user to pick their "Discovery Intensity" (Sustainable vs. Life Changing) *before* they have seen any of their streaks is confusing. They have no context for what these thresholds will actually look like until the engine runs.

## Summary
The app has a strong aesthetic and a clever auto-discovery engine, but the premium conversion loop is hindered by a lack of user agency over Grace Days. Providing manual control over streak saves, making "Freezes" easier to access, and softening the aggressive ALL CAPS typography on longer texts will drastically improve daily retention and Pro satisfaction.