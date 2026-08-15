# Stage 1 — Handoff

> **Status: ✅ COMPLETE & merged to `main`** (PR [#2](https://github.com/nikhilc523/bloom/pull/2), squash-commit `59bb832`).
> Repo: <https://github.com/nikhilc523/bloom>
>
> This document exists so a **new chat can pick up from here** without re-reading the whole conversation. Read this, skim the files it points to, then start the next stage's PROMPT block from [`docs/product/MASTER-BUILD-PLAN.md`](../../product/MASTER-BUILD-PLAN.md).

---

## What Stage 1 was

**Stage 1 — Domain model: full data types + shareability metadata.** Expand the pure value-type domain to the complete data model in [`docs/product/01-data-model.md`](../../product/01-data-model.md), encoding tier (core/advanced) and **shareability in the type system**, so the privacy invariants are enforceable and testable *before* any persistence or UI.

**Hard constraint honoured:** pure `Sendable`/`Codable` value types only. **No SwiftData, no UI, no engine logic.** (Prediction/flag *logic* is Stage 2; the projection *engine* is Stage 10 — this stage is just the types + the metadata they carry.)

---

## What was built (all under `Bloom/Model/`)

| File | Contents |
|---|---|
| `Shareability.swift` | `Shareability` enum (`shareable`/`softenedOptIn`/`neverShareable` + `hasToggle`, `isSharedByDefault`, `canEverReachPartner`); the `SharePermitted` / `NeverShareable` marker protocols; `ShareableEnvelope<V: SharePermitted>`; `FieldTier`; the **`LogField`** catalogue (24 fields → tier + shareability, `neverShareableFields`). |
| `DailyLog.swift` | `DailyLog` (one per day, every field optional) + all field enums/structs: `CrampSeverity` (0–10 clamped), `Mood`, `Energy`, `PMSSymptom`, `SexActivity`, `BloodColor`, `ClotSize`, `PainLocation`, `BasalBodyTemperature`, `CervicalMucus`, `CervicalPosition` (both `Comparable`/ordered), `LHTest`, `Medication`, `Discharge`, `Digestion`, `HeadacheSeverity`, `Craving`, `SkinCondition`, `SleepQuality`, `BodyWeight`, `Libido`, `Note`. |
| `User.swift` | `User` + `LifeStageMode` (`cycle/ttc/pregnancy/postpartum/perimenopause/birthControl/teen`, with `supportsCyclePrediction` and `maxNormalCycleLength`). |
| `Cycle.swift` (extended) | Kept the original lightweight `Cycle` **math helper** untouched; **added** `CycleRecord` (the full persistable entity from the doc) + `OvulationEstimate` + `FertileWindow`. |
| `Prediction.swift` | `Prediction` + `PredictionWindow` (range + confidence, never a bare date) + `PredictionBasis` (`calendar/bbt/symptothermal`). |
| `ClinicalFlag.swift` | `ClinicalFlag` + `FlagType` (9 cases) + `FlagSeverity` (ordered). Message is **guaranteed to end in the clinician nudge** — never a diagnosis. |
| `Sharing.swift` | `SharingPreset` (`minimal/supportive/ttc`), `PartnerLink`, `SharedState`, `MoodWeather`, `PinnedNote`. |
| `Flow.swift` (extended) | Existing `Flow` enum now conforms to `SharePermitted` (`.shareable` — the one default-shared field, as *state* only). |

Tests (Swift Testing) — `BloomTests/`: `ShareabilityTests.swift`, `DailyLogTests.swift`, `SharingModelTests.swift`, `DomainEntityTests.swift`. **59 unit tests across 8 suites, all green** (plus the pre-existing UI test still passing).

---

## The privacy invariant — how it's enforced (this is the whole point of the stage)

The differentiator is consent-gated partner sharing ([`docs/research/03-partner-sharing-privacy.md`](../../research/03-partner-sharing-privacy.md)). Stage 1 makes the invariants *structural*:

- **Compile-time un-representability.** `SexActivity`, `Medication`, `BodyWeight` conform to the `NeverShareable` marker and **not** `SharePermitted`. Anything that needs to be shareable is generic over `V: SharePermitted` (e.g. `ShareableEnvelope`, and the Stage-10 projection engine will be too), so an un-shareable value type **cannot be passed there — it won't compile.**
- **No toggle exists.** `LogField.shareability.hasToggle == false` for the never-shareable fields; `PartnerLink` **drops** any `fieldOverride` for them at init *and* in `setOverride(_:shared:)`. There is no switch to pressure.
- **Private notes.** `Note.shareableText` returns `nil` when `isPrivate` — a Private note can never be surfaced/promoted (value-level gate, since a single instance can't be made type-non-conforming).
- **Mood-weather consent gate.** `MoodWeather` only enters `SharedState` if `isConfirmed`. Enforced at `init` **and** via a `private(set)` property + `setMoodWeather(_:)` — I closed an assignment-bypass leak here during the `swift-bug-finder` pass.
- **`SharedState` carries interpretations only** (phase label, "period started" bool, next-period *window*, gentle-window bool, confirmed mood-weather, TTC fertile window) — never a raw `DailyLog` field. `SharedState.blank` is the residue-free revoke/disconnect view.
- **Hidden ≡ un-logged:** every `DailyLog` field is optional, so "hidden" and "never logged" are the same absence.

> ⚠️ These are the app's reason to exist. Stage 10 (the projection engine) and Stages 11–12 (transport + UI) build directly on these types — **do not weaken them.** Any new field must be classified in `LogField` and, if it's a value type that could be shared, marked `SharePermitted` or `NeverShareable`.

---

## Conventions established (follow these in later stages)

- Pure domain lives in `Bloom/Model/`, value types, `Sendable` + `Codable` + `Equatable`, no framework imports beyond `Foundation`.
- Confidence values clamp to `0...1`; scales clamp to their range; text fields cap length in `init`.
- Swift 6 strict concurrency is on; everything is `Sendable`-clean.
- Tests are Swift Testing (`import Testing`, `@Suite`/`@Test`, `#expect`), one suite per concern, arguments-driven where it reads well.
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

## Next: Stage 2

**Stage 2 — On-device engines: prediction + clinical-flag rules.** Paste the Stage 2 PROMPT block from [`docs/product/MASTER-BUILD-PLAN.md`](../../product/MASTER-BUILD-PLAN.md) into a fresh chat.

What Stage 2 will lean on from Stage 1:
- Extend `CyclePredictor` (already in `Bloom/Model/CyclePredictor.swift`) to the full calendar method → `CyclePrediction` / `Prediction`.
- New `FlagEngine` producing `ClinicalFlag`s — use the `ClinicalFlag` initializer so every message keeps the clinician suffix; boundary-test each threshold (heavy bleeding, irregular, short/long incl. teen widening via `LifeStageMode.maxNormalCycleLength`, missed→pregnancy-test-first, urgent).
- Still pure functions over `[CycleRecord]` / `[DailyLog]` — no persistence/UI/AI.
