---
name: ios-release-validator
description: Pre-ship validation gate for Bloom — runs the full test suite, checks entitlements/privacy strings, HealthKit/CloudKit review requirements, App Store health-data rules, and the privacy/safety invariants. Use before a TestFlight build, a release, or when asked "is this ready to ship?".
---

# iOS Release Validator

The go/no-go checklist before any build leaves the machine. Anything unchecked in **Privacy & Safety** is release-blocking.

## 1. Build & tests green
```bash
xcodebuild test -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' \
  -enableCodeCoverage YES -resultBundlePath TestResults.xcresult CODE_SIGNING_ALLOWED=NO
xcrun xccov view --report TestResults.xcresult      # coverage sanity
```
- Unit (`swift-unit-tests`), snapshot (`snapshot-testing`), and critical UI flows (`xcuitest-writer`) all pass.
- `swift-bug-finder` checklist walked over the release diff; `swift-lint-format` clean.

## 2. Live smoke via automation
Use `ios-ui-automation` to run the key flows on a clean simulator (`simctl erase`), light **and** dark:
- log a period · onboarding · connect partner · **sharing mirror shows only shared items** · send pinned note · **silent revoke blanks partner view**.

## 3. Entitlements & Info.plist
- HealthKit entitlement + background delivery; both `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` present and honest.
- iCloud/CloudKit entitlement; container configured; `.timeSensitive` notification entitlement if used.
- All usage-description strings written for a human, not boilerplate.

## 4. Apple review gates
- **App Store 5.1.3** (health/medical data): compliant; data not used for ads; not shared with third parties without consent.
- HealthKit apps: no storing HealthKit data in iCloud/CloudKit *directly* against guidelines; primary purpose is health.
- **No contraception-efficacy claims** anywhere in UI/metadata (not FDA-cleared — `docs/research/01` §4).
- AI companion: persistent "not a doctor" disclaimer visible; red-flag escalation works; no diagnosis language.
- Mandatory privacy policy linked; App Privacy "nutrition label" in App Store Connect matches actual data flows.

## 5. Privacy & safety invariants (BLOCKING — docs/research/03)
- [ ] Un-shareable fields (sex, contraception, weight, Private notes) provably never reach `SharedState`.
- [ ] Hidden ≡ un-logged in the partner projection — no reveal signal.
- [ ] Silent revoke blanks partner view + purges cache, no notification artifact.
- [ ] Breakup/disconnect purges partner cache & pins; no unilateral re-link.
- [ ] Partner side holds interpretations only, no history, short cache TTL, server-checked access.
- [ ] No partner-side location / "last active" / activity signal.
- [ ] Quiet/Safety exit hides the partner feature in one silent action.
- [ ] No health data used as an ad signal; nothing sensitive sent to the Claude API beyond de-identified context.

## 6. Ecosystem & polish
- Two-way HealthKit sync verified against Apple's built-in Cycle Tracking.
- iCloud sync across two devices; offline behavior graceful.
- Widgets render (Lock Screen countdown, pinned-note home widget).
- Dynamic Type XXL + increased contrast + Reduce Motion all usable (`accessibility-audit`).

## Output
Produce a short go/no-go with each section pass/fail and every failure as a concrete blocker. **Never green-light with an open Privacy & Safety item.**
