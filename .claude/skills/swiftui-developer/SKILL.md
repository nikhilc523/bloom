---
name: swiftui-developer
description: Build features in the Bloom SwiftUI app following its architecture and pink-glass design system — SwiftData models, on-device logic, CloudKit/HealthKit boundaries, and the glass component conventions. Use when implementing or modifying app features/UI.
---

# SwiftUI Developer (Bloom conventions)

How to add code to Bloom so it matches the architecture in `docs/product/` and the design language in `docs/research/05-ai-and-design.md`. Read those first for anything non-trivial.

## Architecture guardrails
- **Two stores, kept separate** (`docs/product/01-data-model.md`): her private data in **SwiftData + CloudKit private DB**; the partner layer in **CloudKit-direct custom zone + CKShare**. Never mix them.
- **On-device by default:** prediction, pattern detection, flag rules, and notification decisions run in local code. Only *language* goes to the Claude API, with de-identified context (phase/symptom-category/cycle-day) — never name/email/location.
- **HealthKit is the sync:** write the reproductive-health samples to HealthKit; that *is* two-way sync with Apple's Cycle Tracking. Live updates via `HKObserverQuery` + background delivery + `HKAnchoredObjectQuery`.
- **Predictions are ranges + confidence**, never single dates — reflect that in every view that shows one (dashed/ghost styling).
- **Sharing = interpretations, not logs.** UI that feeds the partner projection emits derived cues, never raw `DailyLog` fields. Un-shareable fields have no share affordance at all.

## Design system (build once, reuse)
Palette, radius, and shadow tokens from `docs/research/05-ai-and-design.md` §B2–B4. Core reusable pieces:
- `GlassCard` view + `GlassPanel` modifier that **auto-upgrade to `.glassEffect()` on iOS 26** and fall back to `.ultraThinMaterial` below.
- `CycleRing`, `PhaseCard`, `MoodWeatherTile`, `FloatingPinnedNote`, `CalendarGrid` — the component list in §B5.
- Tokens: radius `sm12/md20/lg28/pill`, always `.continuous`; soft shadow `DeepRose @12–18%, r24, y12`; gradient-stroke edge for the lit-glass look.

## SwiftUI conventions
- Use `@Observable` model types (Observation framework), `@State` for view-owned state, `@Environment` for shared services.
- Text styles for Dynamic Type, never fixed sizes. **Never put body/data text on glass** — solid/high-opacity fill behind text (contrast; see `accessibility-audit`).
- Motion: `.spring(response: 0.4, dampingFraction: 0.7)`; respect Reduce Motion.
- Haptics on key interactions (`.impact(.soft)` taps, `.success` on log).
- **Every interactive/asserted view sets `.accessibilityIdentifier`** (see `accessibility-audit`, `ios-ui-automation`) — non-optional for testability.
- Progressive disclosure: home shows one number + one feeling; detail lives at depth-2 via tap-to-expand (§B7).

## Definition of done for a feature
1. Follows the architecture guardrails above.
2. Uses design-system components/tokens, not ad-hoc styling.
3. Has accessibility identifiers + labels.
4. Tests planned via `test-requirements`, implemented via `swift-unit-tests` / `snapshot-testing` / `xcuitest-writer`.
5. Validated live with `ios-ui-automation` (light + dark), bug-checked with `swift-bug-finder`, lint-clean via `swift-lint-format`.
