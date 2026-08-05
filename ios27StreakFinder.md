# iOS 27 compatibility audit: Streak Finder

- Audit date: 2026-08-05
- Runtime: iOS 27.0 (24A5390f)
- Xcode: 26.6 (17F113)
- Scheme: `FitnessStreaks`
- Unit target: `FitnessStreaksTests`
- Overall: Pass with cleanup candidates

## Checks

- Debug build: Pass.
- Unit tests: Pass.
- Normal rebuild after tests: Pass.
- Install and launch smoke test: Pass.
- Runtime UI snapshot: Pass. Get Started rendered.

## Findings

- `Shared/Services/StoreKitService.swift:248` conditionally casts `NSDecimalNumber` to the same type, so the cast always succeeds.
- `FitnessStreaks/Views/Components/StreakPicker.swift:684` has a default switch branch that is never executed.
- `FitnessStreaksTests/PaidFeatureTests.swift` contains numerous main-actor isolation warnings.
- `FitnessStreaksTests/CustomStreakEdgeCaseTests.swift` declares unused `byDay` and `today` values.
- No iOS 27-specific compiler error or runtime blocker was observed.

## Recommended follow-up

- Simplify the StoreKit cast and switch, then clean test actor isolation and unused values.
