---
name: stage-review
description: End-of-stage adversarial review gate for Bloom — after a build-plan stage lands, hunt HIGH-severity bugs and "does this break the app?" regressions across the whole stage diff, not just one file. Runs automatically on every PR (see .github/workflows/stage-review.yml) and can be invoked manually as /stage-review. Verdict is BLOCK / WARN / PASS with concrete repros.
---

# Stage Review — the per-stage "does it break?" gate

A whole-stage PR review, tuned to *this* app. Each stage of `docs/product/MASTER-BUILD-PLAN.md` (persistence, CloudKit sync, HealthKit, UI…) ships as one PR; this skill reviews that PR the way a senior reviewer would before merge: **find the high-potential bugs and the ways the change breaks the app**, prove them, and return a go/no-go.

It complements — does not replace — the other gates:
- `swift-bug-finder` = line-level bug classes on a diff. **stage-review** = whole-stage, "did we regress the build/tests/privacy/data model" altitude.
- `github-push` = the mechanical push checklist. **stage-review** = the *judgement* that the stage is actually sound.
- `ios-release-validator` = ship/no-ship at release. **stage-review** = per-stage, every PR.

## When it runs
- **Automatically** on every pull request (`opened`/`synchronize`) via `.github/workflows/stage-review.yml`. Posts findings on the PR.
- **Manually**: `/stage-review` (reviews the current branch diff vs `main`).

## Scope of the review
Review the **entire stage diff**, not a single file:
```bash
git fetch origin main
git diff --stat origin/main...HEAD      # what the stage touched
git diff origin/main...HEAD             # the review target
```
Read the stage's handoff/PROMPT in `docs/product/MASTER-BUILD-PLAN.md` and the relevant `docs/handoffs/stage-*/` if present — a change is a bug if it violates the stage's own contract, even when it compiles.

## The hunt — HIGH-potential bugs & breakage (ranked)

### P0 — Privacy / safety invariants (this app's whole reason to exist)
Hard constraints from `docs/research/03-partner-sharing-privacy.md`. Any path that violates one is an automatic **BLOCK**:
- An un-shareable field (sex activity, contraception, weight, Private note, red-flag symptoms) able to reach `SharedState` / the partner zone.
- "Hidden" being observably different from "never logged."
- Revoke / breakup not purging the partner cache.
- Raw logs or clinical flags computed off-device or sent off-device.
- A flag message that reads as a **diagnosis** instead of "…may be worth discussing with a clinician."

### P0 — Does it build & do tests pass?
- Does `xcodegen generate` + `xcodebuild test` still pass? (CI's Build & Test is the source of truth — if red, that's a BLOCK, name the failing test.)
- New files added to `project.yml` sources? (`.xcodeproj` is generated — a new `.swift` not picked up silently isn't compiled.)
- Any test weakened/deleted/`.disabled` to make the stage "pass"? Flag it.

### P0 — Crashes
- `!`, `try!`, `as!`, force-unwrapped optionals from CloudKit/HealthKit/SwiftData/JSON — runtime values, never force.
- Array index / `Calendar` date-component unwraps in cycle math.

### P1 — Data model / persistence integrity (esp. Stage 3+)
- SwiftData + CloudKit mirroring: **every attribute optional or default-valued**, **no `@Attribute(.unique)`**, no non-optional relationships — violations fail to sync *silently*.
- Private store (SwiftData) vs shared partner zone (CKShare) kept **separate** — no cross-writes.
- A schema change with **no migration plan** against existing on-device data → data loss on update. BLOCK.
- In-memory container used by tests / `-uiTesting`; the persistent store used by the app — not swapped.

### P1 — Concurrency / data races (Swift 6 strict concurrency)
- `ModelContext` is **not `Sendable`** — never crossed actors or captured in a detached `Task`. Writes on `@MainActor` or a dedicated `@ModelActor`.
- `@MainActor` UI state mutated from a background continuation without hopping back.

### P1 — Domain-logic regressions
- Predictions surfaced as a bare date instead of range + bounded confidence (ghost styling contract).
- Flag engine off-by-one at a threshold; a `Date()` read *inside* an engine (engines must be pure — reference time is a parameter). Predicted cycles must be ignored by rules.

### P2 — Reliability & fit-and-finish
- Un-handled error paths, retain cycles (`[weak self]`), silent `try?` swallowing real failures, dead code that hides intent.

## Procedure
1. Establish the stage: read its section in the build plan + any handoff; note the stage's explicit **in/out of scope** and **Definition of Done**.
2. Diff `origin/main...HEAD`; list every changed file and *why* it changed.
3. Walk the ranked checklist against the diff. For **each** suspected issue, write the **concrete failing scenario** (inputs → wrong behaviour), not a vague worry. If you can't state a repro, it's not a finding — downgrade to a nit.
4. Prefer proof: where feasible, point at the exact line, or note the test that would fail. When a P0/P1 is confirmed and no test covers it, specify the failing test to add (`swift-unit-tests`).
5. Rank findings by severity; **sharing leaks and crashes first**.

## Output — the verdict
Post a single structured comment:

```
## 🔎 Stage Review — <stage name>
Verdict: BLOCK | WARN | PASS

### BLOCK (must fix before merge)
- [P0 privacy] <file:line> — <repro: inputs → wrong result> — <fix / test to add>

### WARN (should fix, not merge-blocking)
- [P1 data-model] <file:line> — <scenario> — <suggested fix>

### Notes / nits
- …

### Checks
- Build & Test CI: <green/red — failing test if red>
- Privacy invariants: <clear / violated>
- Migration plan (if schema changed): <present / MISSING>
```

Rules for the verdict:
- **BLOCK** if any P0 is real (privacy leak, crash, red CI, diagnosis wording, schema change with no migration).
- **WARN** for real P1/P2 that don't break the app or leak data.
- **PASS** only when you actively looked for the above and found nothing real — say what you checked, don't just declare it clean.
- Be adversarial but honest: a false BLOCK wastes a stage; a missed P0 ships a leak. State uncertainty explicitly rather than inflating or hiding it.
