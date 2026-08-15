# Bloom — Master Build Plan

> **This file is the steering document for building Bloom across many chats.**
> Each numbered stage is a self-contained unit of work you take into its **own fresh chat**, drive end-to-end (branch → code → tests → green CI → merge), validate in the running app, then come back here and start the next stage.

---

## Context — why this plan exists

Bloom is a privacy-first iOS period tracker whose differentiator is **respectful, consent-gated partner sharing** (she tracks; her partner sees only interpretations she chooses, never her diary). The repo today has: a **buildable scaffold** — pure value-type domain (`Flow`, `Cycle`, `CyclePredictor`), a pink-glass design system (`GlassCard` + tokens), scaffold UI (`CycleRing`/`ContentView`/`LogSheet`), unit + UI tests, and green CI on branch-protected `main`. **There is zero persistence** — all state is ephemeral `@State`; no SwiftData, CloudKit, or HealthKit.

The product/data/privacy specs are fully written in `docs/product/` and `docs/research/`. This plan turns those specs into an executable, **data-first** sequence: we lock the domain model, on-device logic, persistence, and sync **before** the real UI, because (a) the data model + privacy invariants are the riskiest thing to retrofit, and (b) you'll supply UI designs later. UI-heavy stages come after the data foundation is solid and tested.

**Confirmed constraints for this plan:** ~14 stages, one layer/feature per stage. You have a **paid Apple Developer account + physical iPhone(s)**, so iCloud sync, HealthKit, and CKShare partner stages are sequenced in their natural order (with "test on device" notes where the simulator falls short).

---

## How to use this plan (repeat every stage, in a new chat)

1. Open a fresh chat. Paste that stage's **PROMPT** block (each stage has one below).
2. The prompt names the **skills to load** — invoke them via the Skill tool. The mandatory `github-push` skill + root `CLAUDE.md` gate every push.
3. Work the stage: branch off `main`, implement, add tests, build/run, validate.
4. Ship it: local `xcodebuild test` green → PR → **Build & Test** CI green → squash-merge. (This is the `github-push` gate — never push to `main` directly.)
5. Validate in the app (simulator or device) per the stage's **Definition of Done**.
6. Return here, tick the stage, start the next one.

### Global guardrails (true for every stage)
- **Two stores, never mixed:** her private data → **SwiftData + CloudKit private DB**; partner layer → **CloudKit custom zone + CKShare** (SwiftData can't use a shared DB). Ref `docs/product/01-data-model.md`.
- **On-device by default:** prediction, pattern detection, flag rules, notification decisions are local code. Only *language* goes to the Claude API, with de-identified context (phase / symptom-category / cycle-day) — never name/email/location.
- **Privacy invariants are hard blockers** (`docs/research/03-partner-sharing-privacy.md`): share interpretations not logs; un-shareable fields (sex, contraception, weight, Private notes) have **no share affordance at all**; hidden ≡ un-logged; silent revoke; breakup purges partner cache; no notification on hide/revoke.
- **Predictions are ranges + confidence, never single dates** — reflect in every view (ghost/dashed styling).
- **Every interactive/asserted view sets `.accessibilityIdentifier`** (testability + a11y).
- **Swift 6 strict concurrency** (already on); everything `Sendable`-clean.
- **New behavior ships with a test** at the cheapest layer (unit → snapshot → UI).
- **Never claim contraception efficacy.** AI is always-disclaimed with hard red-flag escalation.
- iOS **17 baseline**; iOS **26** unlocks native `.glassEffect()` via graceful fallback.

---

## Skills: what we have, what each stage must author

**Existing skills** (`.claude/skills/`): `swiftui-developer`, `ios-build-run`, `ios-ui-automation`, `xcuitest-writer`, `swift-unit-tests`, `snapshot-testing`, `swift-bug-finder`, `test-requirements`, `swift-lint-format`, `accessibility-audit`, `ios-release-validator`, `github-push`.

**Skills to author as we reach them** (each is created *inside* the stage that first needs it — the stage prompt says so, and to search public sources like the Apple docs / community skill repos, then write a `SKILL.md`):

| New skill | Authored in | Purpose |
|---|---|---|
| `swiftdata-cloudkit-setup` | Stage 3 | `@Model` schema, `ModelContainer`, in-memory test container, private-DB CloudKit config, migrations |
| `healthkit-integration` | Stage 5 | HK authorization, category/quantity sample mapping, `HKObserverQuery` + background delivery + `HKAnchoredObjectQuery`, entitlements/usage strings |
| `claude-api-integration` | Stage 8 | On-device Claude calls, model routing, frozen cached safety prompt, streaming, refusal handling, de-identified context |
| `ios-notifications` | Stage 8 | `UNUserNotificationCenter`, quiet hours, cadence cap, no lock-screen leak, `.timeSensitive` entitlement |
| `widgetkit-setup` | Stage 9 | WidgetKit Lock-Screen `.accessoryCircular` + home widget, timeline, App Group data sharing |
| `cloudkit-sharing` | Stage 11 | CKShare invite/accept, custom zone, `CKDatabaseSubscription`, server-authoritative access checks, TTL cache, silent revoke/purge |
| `app-store-submission` | Stage 14 | Archive, App Store Connect, privacy nutrition labels, 5.1.3 health rules, TestFlight, review iteration |

Each new skill follows the existing `SKILL.md` format (`name` + `description` frontmatter) and is committed as part of that stage's PR, so it's reusable in later stages and future chats.

---

## Stage overview

| # | Stage | Layer | Depends on | New skill |
|---|---|---|---|---|
| 1 | Domain model — full data types + shareability metadata | Data | — | — |
| 2 | On-device engines — prediction + clinical-flag rules | Logic | 1 | — |
| 3 | SwiftData persistence (private store) + repository | Persistence | 1,2 | `swiftdata-cloudkit-setup` |
| 4 | iCloud sync (CloudKit private DB) | Sync | 3 | — |
| 5 | HealthKit two-way sync | Sync | 3 | `healthkit-integration` |
| 6 | Design-system hardening + component library | UI foundation | — (parallel-able) | — |
| 7 | Solo logging + home UI (wire data → UI) | UI | 3,6 | — |
| 8 | Phase insights + sparse notifications | Feature + AI | 3,7 | `claude-api-integration`, `ios-notifications` |
| 9 | Lock-Screen / home widget | Feature | 3,7 | `widgetkit-setup` |
| 10 | Sharing projection engine ("what he sees") — pure logic | Data (privacy) | 1,2 | — |
| 11 | CloudKit sharing: CKShare invite + PartnerLink lifecycle | Sync (partner) | 3,10 | `cloudkit-sharing` |
| 12 | Partner UI: presets, live mirror, pinned notes, silent revoke/exit | UI (partner) | 11 | — |
| 13 | Ask Bloom chat (Sonnet 4.6, streaming, safety) | AI | 8 | — |
| 14 | Pattern detection + charts + doctor export + ship-readiness | Depth + release | most | `app-store-submission` |

Stage 6 (design system) has no data dependency and can be slotted earlier if you'd rather warm up on UI — but 1→5 first keeps the plan data-first as intended.

---

## The stages

Each stage below has: **Goal · Scope (in/out) · Key files · Data/interfaces · Skills · Definition of Done · PROMPT** (the block to paste into a new chat).

---

### Stage 1 — Domain model: full data types + shareability metadata

**Goal.** Expand the pure value-type domain to the complete data model in `docs/product/01-data-model.md`, encoding tier (core/advanced) and **shareability in the type system** — so the privacy invariants are enforceable and testable *before* any persistence or UI.

**In scope.** `DailyLog` and all its field enums (core: `flow`, `crampSeverity`, `mood`, `energy`, `pms`, `sexActivity`; advanced: `bloodColor`, `clotSize`, `painLocation`, `bbt`, `cervicalMucus`, `cervicalPosition`, `lhTest`, `medication`, `discharge`, `weight`, `note{isPrivate}`, etc.); `User` + `lifeStageMode`; extended `Cycle`; `Prediction`; `ClinicalFlag` + types; `PartnerLink`; `SharedState`; `PinnedNote`. A `Shareability` enum/metadata layer marking each field `shareable`/`softenedOptIn`/`neverShareable`. All pure, `Sendable`, `Codable`, unit-tested. **No SwiftData, no UI.**

**Out.** Persistence, prediction/flag *logic* (Stage 2), the projection *engine* (Stage 10) — just the types + the metadata they carry.

**Key files.** New files under `Bloom/Model/` (extend existing `Flow.swift`, `Cycle.swift`); new `Bloom/Model/DailyLog.swift`, `User.swift`, `Prediction.swift`, `ClinicalFlag.swift`, `Sharing.swift` (PartnerLink/SharedState/PinnedNote + `Shareability`). Tests in `BloomTests/`.

**Skills.** `test-requirements` (map fields → cases, incl. privacy cases) → `swiftui-developer` (conventions) → `swift-unit-tests` → `swift-bug-finder` → `swift-lint-format` → `github-push`.

**Definition of Done.** Every field from the data-model doc exists with correct type/tier; un-shareable fields are *un-representable* as shareable (compile-time or asserted); unit tests cover enum completeness + shareability metadata; CI green.

**PROMPT.**
> We're building Bloom (privacy-first iOS period tracker). This is **Stage 1 of `docs/product/MASTER-BUILD-PLAN.md`: the domain model layer** — pure value types only, no persistence, no UI.
> Load skills: `test-requirements`, `swiftui-developer`, `swift-unit-tests`, `swift-bug-finder`, `swift-lint-format`, and `github-push` (mandatory before any push — see `CLAUDE.md`).
> Read `docs/product/01-data-model.md` (full entity/field spec) and `docs/research/03-partner-sharing-privacy.md` (shareability rules). Then implement the complete domain as pure `Sendable`/`Codable` value types under `Bloom/Model/`: `DailyLog` + all field enums, `User`+`lifeStageMode`, extended `Cycle`, `Prediction`, `ClinicalFlag`+types, `PartnerLink`, `SharedState`, `PinnedNote`. Add a `Shareability` metadata layer so un-shareable fields (sex, contraception, weight, Private notes) **cannot be represented as shareable**. Exhaustively unit-test (Swift Testing) enum completeness and shareability metadata, including the privacy invariant cases. Do NOT add SwiftData or wire any UI. Ship via the `github-push` gate: branch → local `xcodebuild test` green → PR → green CI → merge.

---

### Stage 2 — On-device engines: prediction + clinical-flag rules

**Goal.** Flesh out the calendar-method prediction engine (confidence bands per spec) and build the **clinical-flag rule engine** as pure, deterministic, exhaustively tested functions.

**In scope.** Extend `CyclePredictor` to the spec (average + regularity + data-weight → range + confidence, ghost styling contract). New `FlagEngine`: heavy bleeding (flow=heavy consecutive / period >7d / clot ≥2.5cm), irregular (shift ≥7–9d), short/long (<21 or >35; teen ≤45), missed (≥90d → pregnancy-test prompt), urgent (bleeding+dizziness/SOB, inter-menstrual/post-coital, post-menopausal). Every flag message ends "…may be worth discussing with a clinician" — never a diagnosis.

**Out.** Persistence, UI, AI phrasing (Stage 8). Pure functions over `[Cycle]`/`[DailyLog]`.

**Key files.** `Bloom/Model/CyclePredictor.swift` (extend), new `Bloom/Model/FlagEngine.swift`. Tests in `BloomTests/`.

**Skills.** `test-requirements` → `swift-unit-tests` → `swift-bug-finder` → `swiftui-developer` → `swift-lint-format` → `github-push`.

**Definition of Done.** Prediction always a range with bounded confidence; every flag rule has boundary tests (on/off either side of each threshold); no diagnosis language; CI green.

**PROMPT.**
> Bloom, **Stage 2 of `docs/product/MASTER-BUILD-PLAN.md`: on-device prediction + clinical-flag engines.** Pure functions, no persistence/UI.
> Load: `test-requirements`, `swift-unit-tests`, `swift-bug-finder`, `swiftui-developer`, `swift-lint-format`, `github-push`.
> Read `docs/product/01-data-model.md` (Prediction + ClinicalFlag thresholds) and `docs/research/05-ai-and-design.md` (uncertainty-band contract). Extend `CyclePredictor` to the full calendar method (range + confidence from average/regularity/data-weight). Build a new `FlagEngine` implementing every threshold (heavy bleeding, irregular, short/long incl. teen widening, missed→pregnancy-test-first, urgent). Every flag message ends "…may be worth discussing with a clinician"; never diagnose. Boundary-test each rule on both sides of its threshold with Swift Testing. Ship via `github-push`.

---

### Stage 3 — SwiftData persistence (private store) + repository

**Goal.** Persist her data. Introduce SwiftData `@Model` entities mirroring the domain, a `ModelContainer` (with an **in-memory** container for tests + the `-uiTesting` path already stubbed in `BloomApp.swift`), and a repository/service layer the app talks to. CloudKit-private-DB-*ready* config but sync itself is Stage 4.

**In scope.** `@Model` classes for User/Cycle/DailyLog/Prediction/ClinicalFlag; mapping to/from the Stage-1 value types (keep pure types for logic, `@Model` for storage); `ModelContainer` factory (persistent + in-memory); a `CycleRepository`/`LogRepository` API; wire `BloomApp.swift` (replace the "Wire real ModelContainer here" TODO). Migration plan documented.

**Out.** CloudKit sync (4), HealthKit (5), real UI beyond minimal binding.

**Key files.** New `Bloom/Store/` (`Models+SwiftData.swift`, `ModelContainer+Bloom.swift`, `Repository.swift`); edit `Bloom/BloomApp.swift`. Tests use in-memory container.

**Skills.** **Author `swiftdata-cloudkit-setup`** (search Apple SwiftData docs + community skills first) → `swiftui-developer` → `swift-unit-tests` → `swift-bug-finder` → `github-push`.

**Definition of Done.** App launches with a persistent store; logs survive relaunch; tests run against an in-memory container; `-uiTesting` uses in-memory; no data-race warnings; CI green; `swiftdata-cloudkit-setup` skill committed.

**PROMPT.**
> Bloom, **Stage 3: SwiftData persistence (private store) + repository** from `docs/product/MASTER-BUILD-PLAN.md`.
> First **author a new skill** `.claude/skills/swiftdata-cloudkit-setup/SKILL.md` (search current Apple SwiftData/CloudKit docs + reputable public Claude-skill repos; follow our existing `SKILL.md` format). Then load: `swiftdata-cloudkit-setup`, `swiftui-developer`, `swift-unit-tests`, `swift-bug-finder`, `github-push`.
> Read `docs/product/01-data-model.md` (storage-architecture table). Add SwiftData `@Model` entities for User/Cycle/DailyLog/Prediction/ClinicalFlag under `Bloom/Store/`, with mapping to the Stage-1 pure value types. Provide a `ModelContainer` factory (persistent + in-memory) configured **CloudKit-private-DB-ready but sync OFF for now**. Add a repository layer the UI will call. Replace the `ModelContainer` TODO in `BloomApp.swift`; route `-uiTesting` to an in-memory store. Unit-test persistence round-trips on the in-memory container. Ship via `github-push`.

---

### Stage 4 — iCloud sync (CloudKit private DB)

**Goal.** Turn on cross-device sync for her private store via CloudKit private DB (`NSPersistentCloudKitContainer`-equivalent for SwiftData), entitlements, container identifier, conflict handling. Verify on two devices.

**In scope.** Enable CloudKit on the SwiftData container; add iCloud/CloudKit capability + container to entitlements/`project.yml`; handle first-run schema push; verify create-on-A → appears-on-B. Graceful offline.

**Out.** HealthKit (5), partner/shared zone (11).

**Key files.** `project.yml` (entitlements/capabilities), `Bloom/Store/ModelContainer+Bloom.swift`, a `Bloom/Bloom.entitlements`.

**Skills.** `swiftdata-cloudkit-setup` (from 3) → `ios-release-validator` (entitlements/usage strings) → `swift-bug-finder` → `github-push`. Test on device.

**Definition of Done.** A log created on one signed-in device appears on a second within sync latency; offline edits reconcile; CI green (sync itself validated manually on device — note this in the PR).

**PROMPT.**
> Bloom, **Stage 4: iCloud sync via CloudKit private DB** from `docs/product/MASTER-BUILD-PLAN.md`. I have a paid dev account + two iPhones.
> Load: `swiftdata-cloudkit-setup`, `ios-release-validator`, `swift-bug-finder`, `github-push`.
> Enable CloudKit private-DB sync on the SwiftData container from Stage 3; add the iCloud/CloudKit capability, container identifier, and entitlements in `project.yml` + a `Bloom.entitlements`. Handle initial schema deployment and conflict/offline reconciliation. Keep the two-store rule intact (this is her PRIVATE DB only; no shared zone yet). Walk me through provisioning + the on-device two-phone verification. Ship via `github-push`; note in the PR that cross-device sync was validated on device.

---

### Stage 5 — HealthKit two-way sync

**Goal.** Make writing reproductive-health samples to HealthKit *be* the two-way sync with Apple Cycle Tracking. Authorization, sample mapping, live observation.

**In scope.** HK authorization (read+write); map fields to `HKCategoryType` (menstrualFlow, ovulationTestResult, cervicalMucusQuality, intermenstrualBleeding, sexualActivity, contraceptive, pregnancy, lactation…) + `basalBodyTemperature` (`HKQuantityType`); write-through on log; ingest external changes via `HKObserverQuery` + background delivery + `HKAnchoredObjectQuery`; entitlements + `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription`. Handle "can't read *read*-authorization status" gotcha.

**Out.** UI polish; partner layer.

**Key files.** New `Bloom/Health/HealthKitSync.swift`; `project.yml` (HealthKit + background-delivery entitlements, usage strings).

**Skills.** **Author `healthkit-integration`** (search Apple HealthKit docs first) → `swift-bug-finder` → `ios-release-validator` → `github-push`. Test on device (HealthKit is limited in simulator).

**Definition of Done.** Logging a period in Bloom shows in Apple Health and vice-versa; background changes ingest; auth flow correct; `healthkit-integration` skill committed; CI green.

**PROMPT.**
> Bloom, **Stage 5: HealthKit two-way sync** from `docs/product/MASTER-BUILD-PLAN.md`. Testing on a physical iPhone.
> First **author** `.claude/skills/healthkit-integration/SKILL.md` (search current Apple HealthKit docs; our SKILL.md format). Then load: `healthkit-integration`, `swift-bug-finder`, `ios-release-validator`, `github-push`.
> Read the HealthKit section of `docs/product/02-build-plan.md`. Implement `Bloom/Health/HealthKitSync.swift`: authorization, field→sample mapping (category types + BBT quantity), write-through on log, and live ingest via `HKObserverQuery` + background delivery + `HKAnchoredObjectQuery`. Add entitlements + both usage strings in `project.yml`. Respect the "can't read read-auth status" gotcha. Guide me through on-device verification both directions (Bloom↔Apple Health). Ship via `github-push`.

---

### Stage 6 — Design-system hardening + component library

**Goal.** Turn the current tokens + `GlassCard` into the full pink-glass component library, locked with snapshot tests — ready for real screens (and your incoming UI designs).

**In scope.** Complete palette/typography/radius/shadow tokens (`docs/research/05-ai-and-design.md` §B2–B4); `GlassPanel` modifier + `GlassCard` **auto-upgrading to `.glassEffect()` on iOS 26** with `.ultraThinMaterial` fallback; component stubs `PhaseCard`, `MoodWeatherTile`, `FloatingPinnedNote`, `CalendarGrid` (+ existing `CycleRing`); motion token `.spring(response:0.4,dampingFraction:0.7)`; Reduce-Motion + contrast rules (glass never behind body text). Snapshot tests lock rendering.

**Out.** Real data binding (Stage 7), Rive 3D-emoji runtime (can be a placeholder now; wire later).

**Key files.** `Bloom/DesignSystem.swift` (extend), new `Bloom/Components/*.swift`. Snapshot tests via pointfreeco/swift-snapshot-testing.

**Skills.** `swiftui-developer` → `snapshot-testing` (adds the SnapshotTesting dep) → `accessibility-audit` → `swift-lint-format` → `github-push`.

**Definition of Done.** All six components render in light/dark; snapshot suite green and committed; contrast/Dynamic-Type audited; CI green (note: snapshot deps added).

**PROMPT.**
> Bloom, **Stage 6: design-system hardening + component library** from `docs/product/MASTER-BUILD-PLAN.md`.
> Load: `swiftui-developer`, `snapshot-testing`, `accessibility-audit`, `swift-lint-format`, `github-push`.
> Read `docs/research/05-ai-and-design.md` §B (tokens, components, motion, disclosure). Extend `Bloom/DesignSystem.swift` to the full palette/typography/radius/shadow tokens; ship a `GlassPanel` modifier + `GlassCard` that auto-upgrade to `.glassEffect()` on iOS 26 and fall back to `.ultraThinMaterial`. Build components under `Bloom/Components/`: `PhaseCard`, `MoodWeatherTile`, `FloatingPinnedNote`, `CalendarGrid` (predicted days dashed/ghost). Respect Reduce Motion + "glass never behind body text." Lock every component with snapshot tests (light+dark) and audit a11y/contrast. Ship via `github-push`.

---

### Stage 7 — Solo logging + home UI (wire data → UI)

**Goal.** The real solo experience: log daily (core-minimal, progressive disclosure), home shows the Cycle Ring bound to **persisted** data + Mood Weather + a calendar with ghost predicted days. **This is where your supplied UI designs get implemented.**

**In scope.** Replace the scaffold `ContentView`/`LogSheet` with real screens backed by the Stage-3 repository: daily-log entry (core fields at depth-0, advanced behind tap-to-expand), Cycle Ring from real cycle data, Mood Weather tile, month calendar. Full `.accessibilityIdentifier` coverage. XCUITest for the log flow; live validation.

**Out.** Insights/notifications (8), widget (9), partner (10+).

**Key files.** `Bloom/ContentView.swift`, `Bloom/LogSheet.swift` (rewrite), new screen files under `Bloom/Screens/`; `BloomUITests/`.

**Skills.** `test-requirements` → `swiftui-developer` → `accessibility-audit` → `snapshot-testing` → `xcuitest-writer` → `ios-build-run` → `ios-ui-automation` → `swift-bug-finder` → `github-push`.

**Definition of Done.** Log a period → persists → ring/calendar reflect it after relaunch; predicted days render ghost; XCUITest passes in CI; live UI validated light+dark; CI green.

**PROMPT.**
> Bloom, **Stage 7: solo logging + home UI** from `docs/product/MASTER-BUILD-PLAN.md`. (I'll paste UI designs in this chat.)
> Load: `test-requirements`, `swiftui-developer`, `accessibility-audit`, `snapshot-testing`, `xcuitest-writer`, `ios-build-run`, `ios-ui-automation`, `swift-bug-finder`, `github-push`.
> Using the Stage-6 components and the Stage-3 repository, build the real solo screens: daily-log entry (core-minimal at depth-0, advanced behind tap-to-expand per §B7 progressive disclosure), a home with the Cycle Ring bound to persisted data, Mood Weather, and a month calendar with predicted days as ghost/dashed. Every interactive view gets an `.accessibilityIdentifier`. Write an XCUITest for the log→persist→reflect flow; validate live with `ios-ui-automation` in light+dark. Ship via `github-push`. Wait for my UI before finalizing visuals.

---

### Stage 8 — Phase insights + sparse notifications

**Goal.** Warm, honest phase-insight cards (Haiku over a clinician-reviewed template floor) and **sparse, leak-proof** local notifications.

**In scope.** Claude API client (on-device, de-identified context, model routing, refusal handling, frozen cached safety prompt); phase-insight cards over a template library (template floor if API unavailable); notification engine: nightly decision, quiet hours, ≤3–4/cycle cap, anticipatory tone, **no health data on lock screen** ("Bloom has a note for you"). `.timeSensitive` entitlement.

**Out.** Chat (13), pattern detection (14), partner AI cues (12).

**Key files.** New `Bloom/AI/ClaudeClient.swift`, `Bloom/AI/PhaseInsights.swift`, `Bloom/Notifications/NotificationEngine.swift`; entitlements in `project.yml`.

**Skills.** **Author `claude-api-integration`** and **`ios-notifications`** (search Anthropic API docs + Apple UN docs) → `swiftui-developer` → `swift-unit-tests` → `swift-bug-finder` → `github-push`. Key handling per `claude-api` conventions; never commit secrets (github-push blocks it).

**Definition of Done.** Insight card shows (template floor with no network); a scheduled notification fires with discreet copy, respecting quiet hours + cap; API key stays out of git; both new skills committed; CI green.

**PROMPT.**
> Bloom, **Stage 8: phase insights + sparse notifications** from `docs/product/MASTER-BUILD-PLAN.md`.
> First **author** `.claude/skills/claude-api-integration/SKILL.md` and `.claude/skills/ios-notifications/SKILL.md` (search Anthropic API + Apple UserNotifications docs). Then load those + `swiftui-developer`, `swift-unit-tests`, `swift-bug-finder`, `github-push`.
> Read `docs/research/05-ai-and-design.md` Part A (AI routing, guardrails, notification intelligence). Build an on-device `ClaudeClient` (Haiku 4.5 for insights; de-identified context only; frozen cached safety prompt; refusal handling) with a **template floor** so insights work offline. Build phase-insight cards and a notification engine (nightly decision, quiet hours, ≤3–4/cycle, no health data on lock screen, `.timeSensitive` entitlement). Keep the API key out of git (the `github-push` gate blocks secrets). Ship via `github-push`.

---

### Stage 9 — Lock-Screen / home widget

**Goal.** A WidgetKit Lock-Screen `.accessoryCircular` period countdown + a home-screen widget surface, fed from the store via an App Group.

**In scope.** Widget extension target in `project.yml`; App Group for data sharing; timeline provider from the repository (period countdown as a window, not a hard date); home widget as the hero surface (later hosts pinned notes). (Live Activity explicitly deferred — poor fit for multi-day countdown.)

**Out.** Partner pinned-notes in the widget (comes after Stage 12).

**Key files.** New `BloomWidgets/` target; `project.yml` (widget target + App Group); shared read API in `Bloom/Store/`.

**Skills.** **Author `widgetkit-setup`** (search Apple WidgetKit docs) → `swiftui-developer` → `snapshot-testing` → `github-push`.

**Definition of Done.** Widget shows the current countdown/phase and updates from the store; App Group wired; `widgetkit-setup` skill committed; CI builds the widget target; validated on device.

**PROMPT.**
> Bloom, **Stage 9: Lock-Screen / home widget** from `docs/product/MASTER-BUILD-PLAN.md`.
> First **author** `.claude/skills/widgetkit-setup/SKILL.md` (search Apple WidgetKit docs). Then load it + `swiftui-developer`, `snapshot-testing`, `github-push`.
> Add a `BloomWidgets` extension target in `project.yml` sharing data with the app via an App Group. Build a Lock-Screen `.accessoryCircular` period-countdown widget (window language, never a hard date) and a home-screen widget surface fed by the Stage-3 repository. Defer Live Activity. Snapshot the widget views; validate on device. Ship via `github-push`.

---

### Stage 10 — Sharing projection engine ("what he sees") — pure logic

**Goal.** The privacy heart, built as **pure, exhaustively tested logic before any CloudKit**: given her `DailyLog` + preset + overrides, derive the `SharedState` the partner may see — interpretations only, with un-shareable fields structurally impossible to leak.

**In scope.** A `SharingProjection` engine mapping (logs, `sharingPreset` ∈ minimal/supportive/ttc, `fieldOverrides`) → `SharedState` (phase label, period-started flag, next-period *window*, gentle-window bool, she-confirmed mood-weather, TTC fertile window only in TTC mode). Enforce: un-shareable fields have no path to output; **hidden ≡ un-logged** (identical projection); softened cues describe *his* behavior not *her* deficiency. Exhaustive unit tests including adversarial privacy cases.

**Out.** CloudKit transport (11), UI (12).

**Key files.** New `Bloom/Sharing/SharingProjection.swift` (builds on Stage-1 `Sharing.swift`). Heavy `BloomTests/` coverage.

**Skills.** `test-requirements` (privacy/safety cases are mandatory) → `swift-unit-tests` → `swift-bug-finder` → `swiftui-developer` → `github-push`.

**Definition of Done.** Projection provably emits only allowed derived cues per preset; property tests show a hidden field and an un-logged field yield identical output; no un-shareable field can appear; CI green. Consider running `swift-bug-finder` specifically for leak paths.

**PROMPT.**
> Bloom, **Stage 10: the sharing projection engine (pure logic)** from `docs/product/MASTER-BUILD-PLAN.md`. No CloudKit/UI yet — this is the privacy core, tested first.
> Load: `test-requirements`, `swift-unit-tests`, `swift-bug-finder`, `swiftui-developer`, `github-push`.
> Read `docs/research/03-partner-sharing-privacy.md` (invariants, default matrix, mood-weaponization guardrails) and the `SharedState`/`PartnerLink` spec in `docs/product/01-data-model.md`. Build `Bloom/Sharing/SharingProjection.swift`: (logs, preset[minimal/supportive/ttc], overrides) → `SharedState` — interpretations only. Enforce structurally: un-shareable fields (sex/contraception/weight/Private) can't reach output; **hidden ≡ un-logged** (identical projection); cues describe his behavior, not her deficiency; TTC window only if both in TTC mode. Write exhaustive + adversarial privacy unit tests. Run `swift-bug-finder` focused on leak paths. Ship via `github-push`.

---

### Stage 11 — CloudKit sharing: CKShare invite + PartnerLink lifecycle

**Goal.** Transport the Stage-10 `SharedState` across accounts via a CloudKit **custom zone + CKShare**, with the full `PartnerLink` lifecycle and server-authoritative access on every fetch.

**In scope.** Custom zone; CKShare invite creation + accept/reject; `PartnerLink` (active/revoked, preset, overrides); push only derived `SharedState` (never raw logs) into the shared zone; `CKDatabaseSubscription` → silent push → fetch; short-TTL partner cache; server-authoritative access check each fetch; **silent revoke** blanks + purges partner cache. Two-account/two-device testing.

**Out.** Partner-side UI + pinned notes UI (12).

**Key files.** New `Bloom/Sharing/CloudKitShare.swift`, `Bloom/Sharing/PartnerSync.swift`; `project.yml` (shared-DB entitlements, subscription background mode).

**Skills.** **Author `cloudkit-sharing`** (search Apple CKShare/CloudKit-sharing docs) → `swift-bug-finder` → `ios-release-validator` → `github-push`. Test with two iCloud accounts on two devices.

**Definition of Done.** Device A invites → B accepts → B sees only projected `SharedState`; revoke on A silently blanks B and purges B's cache with no notification to B; access re-checked server-side each fetch; `cloudkit-sharing` skill committed; CI green; cross-account verified on device.

**PROMPT.**
> Bloom, **Stage 11: CloudKit CKShare + PartnerLink lifecycle** from `docs/product/MASTER-BUILD-PLAN.md`. Two iCloud accounts + two iPhones ready.
> First **author** `.claude/skills/cloudkit-sharing/SKILL.md` (search Apple CKShare / CloudKit-sharing docs). Then load it + `swift-bug-finder`, `ios-release-validator`, `github-push`.
> Read `docs/product/01-data-model.md` (storage table, PartnerLink, SharedState) and `docs/research/03-partner-sharing-privacy.md` (safety/consent §). Implement a CloudKit **custom zone + CKShare**: invite/accept/reject, `PartnerLink` lifecycle, push ONLY the Stage-10 derived `SharedState` (never raw logs), `CKDatabaseSubscription`→silent push→fetch, short-TTL partner cache, server-authoritative access check per fetch, and **silent revoke** that blanks + purges the partner cache with zero notification. Guide the two-account on-device verification. Ship via `github-push`.

---

### Stage 12 — Partner UI: presets, live mirror, pinned notes, silent revoke/exit

**Goal.** The partner-facing experience + her controls: three presets + item overrides, the **live "What [name] sees" mirror**, bidirectional floating pinned notes, and the silent revoke / breakup purge / Quiet-Safety exit.

**In scope.** Her sharing settings (Minimal/Supportive/TTC presets + per-item overrides, un-shareable items have **no toggle**); live mirror rendering exactly the Stage-10 projection; partner-side "this week, in a sentence" view (interpretation, opt-in gestures, soft countdown — no dashboard, no history, no mood timeline, no "last active"); bidirectional `PinnedNote` (love/reminder/highlight, one active pin, mute/dismiss, no read receipts) over the Stage-11 subscription; **Quiet/Safety exit** (revoke + disconnect + hide the whole partner feature in one silent action) + clean-break purge. Optional partner AI cue (Haiku) from Stage 8's client.

**Out.** Anything beyond the partner moat.

**Key files.** New `Bloom/Screens/Sharing/*.swift`, `Bloom/Screens/Partner/*.swift`; XCUITests for connect → mirror → pin → revoke.

**Skills.** `test-requirements` → `swiftui-developer` → `accessibility-audit` → `xcuitest-writer` → `ios-ui-automation` → `swift-bug-finder` → `ios-release-validator` (privacy invariants are ship-blockers) → `github-push`.

**Definition of Done.** The live mirror byte-matches what the partner device shows; hiding an item is invisible on his side; revoke/Quiet-exit are silent and purge his cache; pinned notes flow both ways with mute and no read receipts; XCUITest covers connect/mirror/pin/revoke; `ios-release-validator` privacy gate passes; verified on two devices; CI green.

**PROMPT.**
> Bloom, **Stage 12: partner UI — presets, live mirror, pinned notes, silent revoke/Quiet-exit** from `docs/product/MASTER-BUILD-PLAN.md`. (UI designs incoming in this chat.)
> Load: `test-requirements`, `swiftui-developer`, `accessibility-audit`, `xcuitest-writer`, `ios-ui-automation`, `swift-bug-finder`, `ios-release-validator`, `github-push`.
> Read `docs/research/03-partner-sharing-privacy.md` fully (partner-side framing, mood guardrails, safety/consent, cardinal no-notify rule). Using Stage 10 (projection) + Stage 11 (transport), build: her sharing settings (3 presets + per-item overrides; **un-shareable items have no toggle**); the live "What [name] sees" mirror (must match the partner device exactly); the partner "this week, in a sentence" view (interpretation only — no dashboard/history/mood-timeline/last-active); bidirectional floating pinned notes (one active pin, mute/dismiss, no read receipts); and the **Quiet/Safety exit** (revoke+disconnect+hide feature, silent) + clean-break purge. XCUITest connect→mirror→pin→revoke; pass the `ios-release-validator` privacy gate; verify on two devices. Ship via `github-push`.

---

### Stage 13 — Ask Bloom chat (Sonnet 4.6, streaming, safety)

**Goal.** The warm health companion chat — honest about being AI, streaming, with a frozen cached safety prompt and hard red-flag escalation.

**In scope.** Chat UI (Ask-Bloom pill entry → conversation); Sonnet 4.6 default (Opus 4.8 for rare hard reasoning) via the Stage-8 `ClaudeClient`; streaming; adaptive thinking; persistent disclaimer; hard-coded red-flag escalation list (soaking a pad/hour, bleeding while pregnant, severe one-sided pelvic pain, fainting, post-menopausal bleeding, self-harm → escalate to doctor/emergency); graceful `stop_reason: "refusal"`. No diagnosis, no contraception dosing.

**Out.** Multi-turn memory beyond session; pattern detection (14).

**Key files.** New `Bloom/AI/AskBloom*.swift`, `Bloom/Screens/Chat/*.swift`. Unit tests for red-flag detection; UI test for disclaimer visibility.

**Skills.** `claude-api-integration` (from 8) → `swiftui-developer` → `swift-unit-tests` → `ios-ui-automation` → `swift-bug-finder` → `github-push`.

**Definition of Done.** Streaming replies render; disclaimer always visible; every red-flag phrase triggers escalation copy (unit-tested); refusals handled gracefully; CI green.

**PROMPT.**
> Bloom, **Stage 13: Ask Bloom chat** from `docs/product/MASTER-BUILD-PLAN.md`.
> Load: `claude-api-integration`, `swiftui-developer`, `swift-unit-tests`, `ios-ui-automation`, `swift-bug-finder`, `github-push`.
> Read `docs/research/05-ai-and-design.md` A1 (companion guardrails). Build the Ask-Bloom chat on the Stage-8 `ClaudeClient`: Sonnet 4.6 default (Opus 4.8 rare), streaming, adaptive thinking, frozen cached safety prompt, persistent disclaimer, hard-coded red-flag escalation, graceful refusal handling. No diagnosis / no contraception dosing. Unit-test the red-flag detector exhaustively; UI-test that the disclaimer is always visible. Ship via `github-push`.

---

### Stage 14 — Pattern detection + charts + doctor export + ship-readiness

**Goal.** Close the loop: on-device pattern detection (Haiku only phrases it), depth-2 charts, doctor-visit export, then the full release gate + TestFlight.

**In scope.** On-device statistical pattern-finding (model never invents patterns; Haiku phrases); charts at depth-2 (never depth-0); doctor-visit export (PDF/talking points); run the full `ios-release-validator` gate (tests, entitlements, privacy strings, 5.1.3 health rules, privacy nutrition labels, no contraception claims); archive + TestFlight upload; review-iteration playbook.

**Out.** Wearables, richer widgets, full life-stage modes (post-MVP polish — add as later stages if desired).

**Key files.** New `Bloom/Insights/PatternEngine.swift`, `Bloom/Screens/Insights/*.swift`, `Bloom/Export/DoctorExport.swift`. Release artifacts.

**Skills.** `swift-unit-tests` → `swiftui-developer` → `swift-bug-finder` → `ios-release-validator` → **author `app-store-submission`** (search App Store Connect / TestFlight + 5.1.3 health-data docs) → `github-push`.

**Definition of Done.** Patterns surface as gentle, exportable observations (statistically derived, AI-phrased only); charts live at depth-2; doctor export generates; the release gate passes; a TestFlight build is uploaded; `app-store-submission` skill committed.

**PROMPT.**
> Bloom, **Stage 14: pattern detection + charts + doctor export + ship-readiness** from `docs/product/MASTER-BUILD-PLAN.md`.
> Load: `swift-unit-tests`, `swiftui-developer`, `swift-bug-finder`, `ios-release-validator`, `github-push`; then **author** `.claude/skills/app-store-submission/SKILL.md` (search App Store Connect / TestFlight + App Store 5.1.3 health-data + privacy-label docs).
> Read `docs/research/05-ai-and-design.md` A3 (pattern detection: on-device stats, model only phrases) and `docs/product/02-build-plan.md` compliance gates. Build on-device pattern detection (never invents patterns), depth-2 charts, and a doctor-visit export. Then run the full `ios-release-validator` gate (tests, entitlements, privacy strings, 5.1.3, privacy nutrition labels, no contraception claims), archive, and upload a TestFlight build. Ship via `github-push`.

---

## Verification (per stage + overall)

- **Every stage:** local `xcodegen generate && xcodebuild test -project Bloom.xcodeproj -scheme Bloom -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` is green **before** push; the `github-push` gate enforces branch→PR→green **Build & Test** CI→merge.
- **Logic stages (1,2,10):** exhaustive Swift Testing incl. privacy/boundary cases; `swift-bug-finder` sweep.
- **Persistence/sync stages (3,4,5,11):** in-memory container tests in CI **plus** on-device manual verification (two devices / two accounts / Apple Health round-trip) — noted in the PR.
- **UI stages (6,7,9,12,13):** snapshot tests (light+dark) + XCUITest in CI + live `ios-ui-automation` validation.
- **Privacy-critical stages (10,11,12):** must pass the `ios-release-validator` privacy invariants — these are ship-blockers, not warnings.
- **Overall:** Stage 14's release gate + a green TestFlight build is the definition of "MVP shippable."

## Notes / open decisions to revisit
- **Rive 3D-emoji runtime** is introduced lazily (placeholder in Stage 6; wire the real Rive state-machine when you have assets — can be its own mini-stage).
- **Figma MCP** — if you design in Figma, wire the official Dev Mode MCP before Stage 7/12 so screens can be generated from frames.
- Post-MVP stages (wearable temp, richer widgets, full life-stage modes, Android-never) are intentionally out; append as Stages 15+ when the MVP ships.
