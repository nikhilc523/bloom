---
name: test-requirements
description: Turn a Bloom feature or spec into a concrete test plan — acceptance criteria, the test matrix (unit/snapshot/UI/manual), edge cases, and privacy/safety cases that must be covered. Use when starting a feature, reviewing whether coverage is adequate, or defining "done".
---

# Test Requirements & Planning

Bridge from spec (`docs/product/`) to the concrete tests other skills implement. Produce a short, reviewable plan before writing code — not a bureaucratic document.

## Output shape
For a feature, produce:
1. **Acceptance criteria** — observable "given/when/then" statements that define done.
2. **Test matrix** — each criterion mapped to the cheapest layer that can verify it:
   | Layer | Skill | Use for |
   |---|---|---|
   | Unit (Swift Testing) | `swift-unit-tests` | logic: prediction, flags, sharing rules, cycle math |
   | View/tree | `snapshot-testing` (ViewInspector) | component logic & rendering |
   | Snapshot | `snapshot-testing` | pink-glass visual regression |
   | UI E2E (XCUITest/Maestro) | `xcuitest-writer` | critical multi-screen flows |
   | Agent validation | `ios-ui-automation` | exploratory "does it actually work/look right" |
   | Manual | — | things automation can't judge (haptics, motion feel) |
3. **Edge cases** — enumerate before coding.
4. **Privacy/safety cases** — mandatory for anything touching sharing (see below).

## Push tests down
Prefer the cheapest layer that gives confidence: logic → unit; a rendered card → snapshot; a whole flow → one UI test. Don't UI-test what a unit test can prove.

## Standing edge-case checklist for Bloom
- **Cycles:** irregular / very short / very long / missed; spanning month, year, DST; teen & perimenopause widened ranges; sparse logging (low-confidence predictions).
- **Predictions:** always a range + confidence, never a bare date; degrade gracefully with little data.
- **Flags:** fire exactly at the threshold, not below; every message ends "…discuss with a clinician"; never a diagnosis.
- **Life-stage modes:** switching modes changes active fields, flag bounds, and prediction validity.
- **State:** empty (new user), first period, offline, iCloud unavailable, HealthKit denied.

## Privacy & safety cases — NON-NEGOTIABLE (docs/research/03)
Any feature touching sharing MUST have tests for:
- Un-shareable fields (sex, contraception, weight, Private notes) **never** appear in `SharedState` under any preset/override.
- **Hidden ≡ un-logged** in the partner projection — no badge, gap, or signal reveals that something was hidden.
- **Silent revoke** blanks the partner view and purges his cache; produces **no** notification/artifact.
- **Breakup/disconnect** purges the partner's cached data and pins; no unilateral re-link.
- Partner projection carries **interpretations only** ("gentle window active"), never raw logs, and keeps **no history**.

These are the app's reason to exist — treat a gap here as release-blocking.

## Definition of done (per feature)
- [ ] Acceptance criteria all have a passing test at the right layer.
- [ ] Edge-case checklist reviewed; relevant ones covered.
- [ ] Privacy/safety cases covered (if sharing-adjacent).
- [ ] `swift-bug-finder` checklist walked over the diff.
- [ ] Validated live once via `ios-ui-automation` (structure + screenshot, light & dark).
- [ ] Lint/format clean (`swift-lint-format`).
