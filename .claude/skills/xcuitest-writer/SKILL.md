---
name: xcuitest-writer
description: Write end-to-end XCUITest UI tests for Bloom key flows (log a period, connect a partner, send a pinned note, verify the partner-sees mirror). Use when adding automated UI regression coverage that runs in CI. For free-form interactive validation use ios-ui-automation instead.
---

# XCUITest Writer

UI automation is **XCTest-only** (Swift Testing doesn't cover it). Use this for checked-in, CI-run happy-path coverage of the flows that must never break. For exploratory/agent-driven validation, use `ios-ui-automation`.

## Deterministic test mode
The app must not talk to real CloudKit/HealthKit during UI tests. Gate on a launch argument:
```swift
// In BloomApp
if CommandLine.arguments.contains("-uiTesting") {
    // in-memory ModelContainer, seed fixed fixtures, disable CloudKit sync + real HealthKit
}
```

## Anatomy of a test
```swift
import XCTest

final class LogPeriodUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLogPeriodUpdatesRing() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        app.buttons["logPeriodButton"].tap()
        app.buttons["flowMediumButton"].tap()
        app.buttons["saveLogButton"].tap()

        XCTAssertTrue(app.staticTexts["loggedTodayBadge"].waitForExistence(timeout: 2))
    }
}
```

## Rules
- **Query by `accessibilityIdentifier`, never by visible text** (copy/localization/emoji break it). If a needed view lacks one, add it (see `accessibility-audit`).
- Always `waitForExistence(timeout:)` before asserting — the glass/spring animations mean elements appear async.
- `continueAfterFailure = false` so the first failure is the signal.
- Keep each test one flow; no shared mutable state between tests.

## Flows to cover for Bloom
1. **Log a period** → Cycle Ring advances, "logged today" appears.
2. **Onboarding** → pick a life-stage mode, land on home.
3. **Connect a partner** → invite flow reaches the "linked" state (mock the CKShare accept in `-uiTesting`).
4. **Sharing mirror** → set preset to Minimal, open "What [name] sees", assert only phase + "period started" are visible and nothing from the un-shareable set appears.
5. **Send a pinned note** → compose 💛 note → assert it appears in the recipient projection (in-process mock).
6. **Silent revoke** → revoke sharing, assert the partner projection blanks and no notification artifact is produced.

## Run
```bash
xcodebuild test -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -only-testing:BloomUITests CODE_SIGNING_ALLOWED=NO
```

## Guidance
- UI tests are slow and flakier than unit tests — cover *critical* flows only; push detailed assertions down to `swift-unit-tests`.
- The privacy-critical flows (#4, #6) are the ones worth the UI-test cost — they protect the app's whole reason for existing.
