---
name: snapshot-testing
description: Set up and write snapshot (image-diff) and SwiftUI view-tree tests for Bloom's pink-glass design system using pointfreeco/swift-snapshot-testing and nalexn/ViewInspector. Use when building or changing design-system components (Cycle Ring, glass cards, mood weather) to lock in their rendering.
---

# Snapshot & View Tests (the pink-glass safety net)

The glossy design system is the product's charm and its most regression-prone surface. Snapshot tests pin the *rendered pixels*; ViewInspector pins the *view tree/logic*.

## Packages (SPM, test target only)
- **SnapshotTesting** — `https://github.com/pointfreeco/swift-snapshot-testing`, `from: "1.19.0"` (Swift Testing support since 1.19.0; latest 1.19.x).
- **ViewInspector** — `https://github.com/nalexn/ViewInspector`, `from: "0.10.0"`.

## Snapshot testing (image diff)
```swift
import SnapshotTesting
import SwiftUI
import Testing

@Test @MainActor func periodCardMediumFlow() {
    let view = PeriodCard(day: 3, flow: .medium)
    assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
}
```
- First run **records** a reference PNG under `__Snapshots__/` and fails; commit it. Later runs diff against it.
- Force re-record after an intentional design change:
  ```swift
  withSnapshotTesting(record: .all) {
      assertSnapshot(of: CycleRing(day: 5), as: .image)
  }
  ```
- **Pin one device + OS** for snapshots (colors/blur/fonts differ across simulators). Run snapshot tests on a fixed simulator in CI or they'll flap.
- Snapshot both **light and dark** appearances and a couple of Dynamic Type sizes for each glass component.

## ViewInspector (view-tree logic, no rendering)
```swift
import ViewInspector
import Testing
@testable import Bloom

@Test @MainActor func headerShowsDay() throws {
    let sut = CycleHeader(day: 5)
    // Swift 6 inserts an implicit AnyView — unwrap it:
    let txt = try sut.inspect().implicitAnyView().text().string()
    #expect(txt == "Day 5")
}

@Test @MainActor func logButtonFires() throws {
    try LogButton().inspect().implicitAnyView().button().tap()
}
```
Note the required `.implicitAnyView()` under the Swift 6 compiler.

## What to cover
- **Cycle Ring** at several cycle days/phases (gradient fill + lit edge).
- **Glass cards** — phase card, mood-weather tile, floating pinned note — light/dark + XXL type.
- **Calendar** — solid period dots vs. dashed predicted dots (the uncertainty encoding).
- **Empty/loading states** so they don't regress into ugly glass.

## When NOT to snapshot
- Don't snapshot animation frames or the drifting orbs (non-deterministic) — assert their presence via ViewInspector instead.
- Don't snapshot data-heavy screens that change often; snapshot the *component*, test the *screen* with `swift-unit-tests`/`xcuitest-writer`.

## Run
```bash
xcodebuild test -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -only-testing:BloomSnapshotTests CODE_SIGNING_ALLOWED=NO
```
Review any diff images the failure emits before deciding it's a regression vs. an intended change (then re-record).
