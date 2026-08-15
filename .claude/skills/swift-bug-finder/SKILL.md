---
name: swift-bug-finder
description: Hunt correctness and crash bugs in Bloom's Swift/SwiftUI code — force-unwraps, retain cycles, Swift 6 concurrency/data races, SwiftData+CloudKit threading pitfalls, HealthKit auth misuse, and prediction/flag logic errors. Use when reviewing a diff for bugs, triaging a crash, or before merging risky code.
---

# Swift Bug Finder

Static + tool-assisted bug hunting tuned to *this* app's failure modes. When you find a real bug, write a failing test (`swift-unit-tests`) before fixing.

## Tools
```bash
xcodebuild analyze -scheme Bloom -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'  # Apple static analyzer
swiftlint analyze          # semantic lint (force-unwrap, unused, etc.)
periphery scan             # dead code that hides bugs
```
Turn on **Swift 6 strict concurrency** (`SWIFT_STRICT_CONCURRENCY = complete`) — the compiler then flags most data races for you.

## Bug classes to check (in priority for Bloom)

### 1. Crash-prone unwrapping
- `!`, `try!`, `as!` on anything not provably non-nil. Grep the diff for `!` and justify each.
- Force-unwrapped optionals from CloudKit/HealthKit/JSON — these are *runtime* values, never force them.

### 2. Retain cycles / leaks
- Escaping closures, `Task { }`, Combine `sink`, and delegate patterns capturing `self` strongly → require `[weak self]` (then `guard let self`).
- SwiftUI: a view model holding a closure back to the view.

### 3. Concurrency / data races (Swift 6)
- `ModelContext` is **not `Sendable`** — never pass it across actors or capture it in a detached `Task`. Do writes on `@MainActor`, or use a dedicated `@ModelActor` for background work.
- `@MainActor` UI state mutated from a background continuation → hop back to main.
- Shared mutable singletons without actor isolation.

### 4. SwiftData + CloudKit pitfalls (see docs/product/01-data-model.md)
- CloudKit mirroring requires **every attribute optional or default-valued** and **no `@Attribute(.unique)`** — flag models that violate this; they fail silently to sync.
- The private store (SwiftData) and the shared partner zone (CloudKit-direct/CKShare) must stay **separate** — flag any code that writes partner data into the private container or vice-versa.
- Predictions/flags must be computed on-device; flag any path sending raw logs off-device.

### 5. HealthKit authorization misuse
- `authorizationStatus(for:)` deliberately does **not** reveal *read* permission — never branch on it as if it did.
- Don't assume authorization from a non-error return; only query after `requestAuthorization` completes; treat empty results as "denied or no data", not an error.

### 6. Domain-logic bugs (the ones that hurt users)
- **Predictions** rendered as a single date instead of a range+confidence → wrong and erodes trust.
- **Flag engine** off-by-one at a threshold, or wording that reads as a diagnosis instead of "discuss with a clinician".
- **Sharing leaks** — the highest-severity bug in this app: any code path where an un-shareable field (sex, contraception, weight, Private note) can reach `SharedState`, or where hiding an item is observably different from not-logging it, or where revoke/breakup fails to purge the partner cache. Treat these as P0.
- Date math: cycles crossing month/year, DST, time-zone changes.

## Procedure
1. Read the diff (or `git diff`), not the whole repo.
2. Run the analyzer + `swiftlint analyze` and read their hits.
3. Walk the checklist above against the changed code; for each suspected bug state the concrete failing scenario.
4. Rank by severity — **sharing leaks and crashes first**.
5. For each confirmed bug: a failing test, then the fix. Report what you found, the repro, and the fix.
