---
name: swift-unit-tests
description: Write and run unit/logic tests for the Bloom app using Swift Testing (import Testing) — cycle math, prediction engine, the flag rule-engine, sharing-permission logic, SwiftData models. Use when adding tests for non-UI logic or when a bug needs a regression test.
---

# Swift Unit Tests (Swift Testing)

Use **Swift Testing** (`import Testing`, built into Xcode 16+) for all new logic tests. Keep XCTest only for UI tests (`xcuitest-writer`). Both coexist in one target.

## Core API
```swift
import Testing
@testable import Bloom

@Test func cycleLengthDefaults() {
    #expect(Cycle().lengthDays == 28)          // prints operands on failure
}

@Test func loadsProfile() async throws {
    let p = try #require(await store.profile())  // unwrap-or-stop
    #expect(p.sharingPreset == .supportive)
}

// runs once per argument, in parallel
@Test("valid flow levels", arguments: [Flow.light, .medium, .heavy])
func flowAccepted(_ f: Flow) { #expect(Cycle.isValid(flow: f)) }

@Suite("Cycle math")
struct CycleTests {                              // fresh instance per test = isolation
    @Test func ovulationDay() { #expect(Cycle(len: 28).ovulation == 14) }
}
```

## Traits
- `@Test(.disabled("reason"))`, `@Test(.timeLimit(.minutes(1)))`, `@Test(.tags(.integration))`.
- `@Suite(.serialized)` — opt out of parallelism when tests share a `ModelContext`.
- `@MainActor` on tests that touch main-actor state (most SwiftData/UI-model code).

## What to test in Bloom (priority order)
Map to `docs/product/01-data-model.md`:
1. **Prediction engine** — next-period window + confidence across regular, irregular, sparse-logging, and teen/perimenopause inputs. Assert it returns *ranges*, never single dates.
2. **Flag rule-engine** — each threshold in the data model fires exactly at its boundary and not below (heavy bleeding, <21/>35-day cycles, missed ≥90 days, etc.). Assert every message ends in the "discuss with a clinician" phrasing and never asserts a diagnosis.
3. **Sharing-permission logic** — the default matrix: un-shareable fields (sex, contraception, weight, Private notes) are *never* emitted to `SharedState` regardless of preset/overrides; hidden ≡ un-logged in the partner projection.
4. **Cycle math** — day counting, phase boundaries, edge cases (cycle spanning month/year, DST).
5. **SwiftData models** — validation, defaults, relationships (use an in-memory `ModelContainer`).

## SwiftData in tests — use an in-memory store
```swift
@MainActor
func makeContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Cycle.self, DailyLog.self, configurations: config)
    return container.mainContext
}
```
Never point tests at the CloudKit-backed store. `ModelContext` is not `Sendable` — keep each test's context on one actor (`@MainActor` or `@Suite(.serialized)`).

## Run
```bash
xcodebuild test -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -only-testing:BloomTests \
  -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
```
Read coverage: `xcrun xccov view --report TestResults.xcresult`.

## Guidance
- One behavior per `@Test`; name it after the behavior, not the method.
- Prefer parameterized tests over copy-pasted near-duplicates.
- When fixing a bug, first write the failing test that reproduces it, then fix (see `swift-bug-finder`).
