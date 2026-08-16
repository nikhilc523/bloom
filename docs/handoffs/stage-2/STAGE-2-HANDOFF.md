# Stage 2 — Handoff

> **Status: ✅ COMPLETE & merged to `main`** (PR [#4](https://github.com/nikhilc523/bloom/pull/4), squash-commit `a4bce1b`).
> Repo: <https://github.com/nikhilc523/bloom>
>
> This document exists so a **new chat can pick up from here** without re-reading the whole conversation. Read this, skim the files it points to, then start the next stage's PROMPT block from [`docs/product/MASTER-BUILD-PLAN.md`](../../product/MASTER-BUILD-PLAN.md).

---

## What Stage 2 was

**Stage 2 — On-device engines: prediction + clinical-flag rules.** Flesh out the calendar-method prediction engine (range + confidence per spec) and build the **clinical-flag rule engine** as pure, deterministic, exhaustively-tested functions over the Stage-1 value types.

**Hard constraint honoured:** pure functions over `[CycleRecord]` / `[DailyLog]`. **No persistence, no UI, no AI phrasing** (that is later stages). Everything is deterministic — the engines never read the wall clock; the reference "now" is passed in as `asOf` / `generatedAt`.

---

## What was built

| File | Contents |
|---|---|
| `Bloom/Model/CyclePredictor.swift` (extended) | Full calendar method: **average** → most-likely day, **regularity** (std-dev of past lengths) → band width, **data-weight** (cycle count, saturates at 6) → confidence. Always a range; confidence bounded `[0.3, 0.95]`. New `CyclePrediction.bandWidthDays` and `requiresGhostStyling` (the uncertainty-band contract — always `true`). New `nextPeriodPrediction(lastPeriodStart:history:mode:generatedAt:calendar:)` that maps the day-band onto real dates and returns **`nil`** for life stages without calendar prediction (pregnancy/postpartum/perimenopause). |
| `Bloom/Model/FlagEngine.swift` (new) | Pure, deterministic clinical-flag rule engine. Every flag is built through `ClinicalFlag`, so every message ends in "…may be worth discussing with a clinician" and **never diagnoses**. Also adds a small `AcuteSymptoms` input (dizziness / shortness-of-breath) the daily log doesn't track as first-class fields, and `Flow.isBleeding` / `Flow.isHeavy` helpers. |

Tests (Swift Testing) — `BloomTests/`:
- `FlagEngineTests.swift` (new) — boundary tests on **both sides** of every threshold.
- `CyclePredictorTests.swift` (extended) — band tightness/widening, data-weight, ghost-styling, dated-window mapping, nil for unsupported modes.

**85 unit tests across 9 suites, all green** (up from 59), plus the pre-existing UI test still passing. CI **Build & Test** green on the PR before merge.

---

## The rules the engine implements (`docs/product/01-data-model.md` §Rule thresholds → `docs/research/01` §3)

All thresholds are named `static let` constants on `FlagEngine`, so they're one place to tune.

| Flag (`FlagType`) | Severity | Fires when | Rule id(s) |
|---|---|---|---|
| `heavyBleeding` | attention | heavy flow on **≥2 consecutive days**, OR a period **> 7 days**, OR a clot **`.large` (≥2.5 cm)** | `heavy:consecutive>=2d`, `heavy:period>7d`, `heavy:clot>=2.5cm` |
| `irregularCycle` | attention | recent completed cycle lengths spread **≥ 7 days**. **Suppressed** for `teen` / `postpartum` / `perimenopause` (irregularity expected) | `irregular:shift>=7d` |
| `shortLongCycle` | informational | most recent completed cycle **< 21** or **> mode max** (35 adult, **45 teen** via `LifeStageMode.maxNormalCycleLength`) | `cycle:short<21d`, `cycle:long>Nd` |
| `missedPeriod` | attention | **≥ 90 days** since last logged period → copy prompts a **pregnancy test first**. N/A in `pregnancy` / `postpartum` | `missed:>=90d` |
| `urgent` | urgent | bleeding **+ dizziness/SOB** (from `AcuteSymptoms`), **post-coital** (bleeding + `sexActivity` same day), **inter-menstrual** (bleeding on cycle-day ≥8 and before the pre-menstrual buffer), **post-menopausal** (bleeding after a ≥365-day gap in `perimenopause`) | `urgent:bleeding+dizziness`, `urgent:bleeding+shortnessOfBreath`, `urgent:postCoital`, `urgent:interMenstrual`, `urgent:postMenopausal` |

- **Predicted cycles are ignored** by every rule (only `!isPredicted` records count).
- `FlagEngine.evaluate(cycles:logs:mode:asOf:acute:calendar:)` runs all rules and returns flags **most-severe first**.
- Individual rule functions (`heavyBleedingFlag`, `irregularCycleFlag`, `shortLongCycleFlag`, `missedPeriodFlag`, `urgentFlags`) are `public`/`static` and directly boundary-testable.

---

## Conventions reinforced (follow these in later stages)

- **Engines are pure & deterministic.** No `Date()` inside the engine — the reference time is a parameter (`asOf` / `generatedAt`); a `Calendar` is injectable (tests use a fixed UTC gregorian calendar to avoid DST flakiness). Do the same for any new engine.
- **Never a diagnosis.** Always construct flags via `ClinicalFlag(...)` so the clinician suffix is guaranteed; never hand-format a flag message. Tests assert every message ends in the suffix and contains no diagnosis language.
- **Predictions are always a range + bounded confidence**, rendered ghost/dashed (`requiresGhostStyling`). Never surface a bare date.
- Thresholds live as named constants, sourced with a doc comment pointing at `docs/research/01` §3.
- Tests are Swift Testing, one suite per concern, boundary values on both sides of each threshold.
- **`.xcodeproj` is generated** — run `xcodegen generate` after adding files; it is gitignored, never committed.

---

## How to verify locally (same command CI runs)

```bash
xcodegen generate
xcodebuild test -project Bloom.xcodeproj -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Ship via the **`github-push`** gate (mandatory, see root `CLAUDE.md`): feature branch → local tests green → PR → **green Build & Test CI** → squash-merge → delete branch. `main` is branch-protected; never push to it directly.

---

## Note for whoever picks this up

- The `AcuteSymptoms` red-flag inputs (dizziness / SOB) are **not** stored on `DailyLog` today — they're passed into `urgentFlags` / `evaluate` by the caller (e.g. an Ask-Bloom triage turn). If a later stage decides to persist them, classify the new field in `LogField` and mark its shareability, per the Stage-1 invariant.
- A stray uncommitted `.gitignore` edit that added `docs/` to the ignore list was found in the working tree and **reverted** (it would have silently un-tracked all docs, including handoffs). If you see it reappear, revert it — docs are the committed source of truth.

---

## Next: Stage 3

Paste the Stage 3 PROMPT block from [`docs/product/MASTER-BUILD-PLAN.md`](../../product/MASTER-BUILD-PLAN.md) into a fresh chat. Stage 3 will build on these engines and the Stage-1 types (typically: SwiftData persistence / the `@Model` layer that maps the pure value types to storage).
