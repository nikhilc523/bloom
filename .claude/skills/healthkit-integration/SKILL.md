---
name: healthkit-integration
description: Two-way sync between Bloom's private store and Apple Health (Cycle Tracking) via HealthKit. Authorization done right (the read-status gotcha), the DailyLog↔HKSample field mapping (menstrualFlow + fertility category types + basalBodyTemperature quantity), write-through on log, and live ingest with HKObserverQuery + background delivery + anchored queries. Use when adding, changing, or debugging any HealthKit read/write/observe path, the HK entitlements, or the field mapping.
---

# HealthKit integration (Bloom)

In Bloom, **writing reproductive-health samples to HealthKit _is_ the two-way sync with Apple's Cycle Tracking** — there is no separate sync engine. Bloom writes her logged fields as `HKSample`s into the Health store (Apple's Cycle Tracking reads them), and ingests samples other apps/devices wrote (Apple Watch, other trackers) back into her `DailyLog`. Grounded in Apple's HealthKit docs and `docs/product/02-build-plan.md` (HealthKit section).

**Golden rules for this app**
1. **HealthKit is a _separate source_ from the SwiftData/CloudKit store. Never put HealthKit data into the CloudKit-mirrored container as if it were hers-authored, and never write her CloudKit data to HealthKit blindly** — mirror only the fields with a true HealthKit home (below). App Store 5.1.3 also forbids storing HealthKit data in iCloud/CloudKit; keep the two sources distinct.
2. **Privacy-first still governs.** Only reproductive-health-relevant fields cross to HealthKit. `weight`, `medications`, free-text `note`, `mood`, and partner data do **not** go to HealthKit here (some have no HK type; weight is deliberately kept out per `docs/research/03`). When in doubt, don't mirror it.
3. **Never trust `authorizationStatus(for:)` for _read_ access** (see gotcha below). This is the #1 HealthKit mistake and it silently breaks ingest.

## Availability gate (do this first)
- `HKHealthStore.isHealthDataAvailable()` is **`false` on the Simulator for many types and on iPad** — HealthKit is device-only in practice. Everything HK must no-op cleanly when this is false, exactly like the Stage-4 CloudKit gate. CI (`CODE_SIGNING_ALLOWED=NO`, simulator) never exercises real HK; validation is manual on device.
- Guard every entry point: `guard HKHealthStore.isHealthDataAvailable() else { return }`.

## The authorization gotcha — read status is unknowable by design
To prevent leaking health info, **`authorizationStatus(for:)` reflects only _share/write_ authorization, never _read_.** For a read-only type it returns `.notDetermined` even after the user grants read, and denied reads look identical to "no data exists." So:

- **Never branch app logic on `authorizationStatus(for:)` for a read type.** If reads come back empty, treat it as "no data," never as "denied."
- To decide whether to *show the permission prompt*, use `getRequestStatusForAuthorization(toShare:read:)`. A result of **`.unnecessary` means "asking again will do nothing," NOT "granted."**
- Request read+write together, once, up front:
  ```swift
  try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
  ```
- Requesting authorization does not throw on denial — the call succeeds; you simply may get no data / silent write failures. Design for that.

## Field mapping — DailyLog ⇄ HealthKit (source of truth)
Category types are `HKCategoryType`; BBT is the one `HKQuantityType`. Keep this table and the code's mapping in lockstep; every mapping is deliberately **lossy-safe** (documented where a Bloom value has no exact HK peer).

| DailyLog field | HealthKit type | Value mapping | Notes |
|---|---|---|---|
| `flow: Flow` | `.menstrualFlow` (category) | none→`.none`, spotting→`.light`, light→`.light`, medium→`.medium`, heavy→`.heavy` | **Set metadata `HKMetadataKeyMenstrualCycleStart: true` on the period's first day** — Apple's Cycle Tracking needs it to register a period start. `spotting` has no HK peer → `.light` (documented loss). |
| `bbt: BasalBodyTemperature` | `.basalBodyTemperature` (**quantity**) | `HKQuantity(unit: .degreeCelsius()/.degreeFahrenheit(), doubleValue:)` | Preserve the unit tag; don't convert silently. |
| `cervicalMucus: CervicalMucus` | `.cervicalMucusQuality` (category) | dry→`.dry`, sticky→`.sticky`, creamy→`.creamy`, eggwhite→`.eggWhite` | Bloom has no `watery`; HK has no separate value we drop. |
| `lhTest: LHTest` | `.ovulationTestResult` (category) | negative→`.negative`, positive→`.luteinizingHormoneSurge` | `.indeterminate`/`.estrogenSurge` unused. |
| `sexActivity: SexActivity` | `.sexualActivity` (category) | value `.notApplicable`; metadata `HKMetadataKeySexualActivityProtectionUsed`: protected→`true`, unprotected→`false` | `none` → write nothing. Sex activity is `NeverShareable` to a partner but HealthKit is *her own* Health app, not the partner layer — mirroring it is fine and expected by Cycle Tracking. |

Fields with **no HealthKit home** (do not attempt to write): `crampSeverity`, `mood`, `energy`, `pms`, `bloodColor`, `clotSize`, `painLocation`, `cervicalPosition`, `medications`, `discharge`, `digestion`, `headache`, `cravings`, `skin`, `sleepQuality`, `weight`, `waterIntake`, `libido`, `note`. (`contraceptive`/`pregnancy`/`lactation`/`intermenstrualBleeding` HK types exist but Bloom has no clean source field yet — leave for a later stage rather than fabricate.)

**Dates.** A `DailyLog` describes one calendar day. Write each sample with `start = end =` the log's start-of-day (or noon local to avoid timezone-boundary drift — pick one and keep it). Category samples are point-in-time.

## Write-through on log (hers → Health)
Mirror to HealthKit as a **repository decorator**, so call sites (`ContentView.persistTodaysFlow`, future log UI) stay unchanged and HealthKit stays decoupled:

- A `HealthKitMirroringLogRepository` conforms to `LogRepository`, wraps `SwiftDataRepository`, forwards every call, and **after the inner write succeeds** diffs the day's fields and saves/updates the corresponding `HKSample`s. If the inner write throws, nothing is mirrored.
- **Idempotency.** Re-logging the same day must not pile up duplicate samples. Before saving, delete Bloom-authored samples of that type on that day (query by date predicate **and** `HKSource.default()` / our source), then insert the new one. HealthKit has no upsert.
- Never block the UI on HK. Mirror in a `Task`; a HK failure is logged, never surfaced as a save failure (the SwiftData write already succeeded and is authoritative).

## Live ingest (Health → hers): observe → anchor → merge
Other sources (Apple Watch, other apps) write to Health; Bloom must pull those in.

1. **`HKObserverQuery`** per observed type — fires on any change while the app runs, and (with background delivery) wakes the app in the background. In its handler you **must call the passed `completionHandler()`** or HealthKit throttles/stops delivering. Do the actual fetch, then call it.
2. **`enableBackgroundDelivery(for:frequency:)`** for each type so changes wake the app. Reproductive category types are typically limited to **`.daily`** frequency (HK caps sensitive types); don't assume `.immediate`. Requires the **background-delivery entitlement** (below).
3. **`HKAnchoredObjectQuery`** (or the modern `HKAnchoredObjectQueryDescriptor`) is what actually fetches *what changed* since last time. **Persist the `HKQueryAnchor`** (archive with `NSKeyedArchiver`, store in `UserDefaults`/file) so each run only ingests the delta — added *and* deleted samples.
4. **Merge into `DailyLog`** via the repository upsert (read the day's log, set the mapped field, upsert). This is `@MainActor` work (`ModelContext` is main-actor-bound).

### Avoid the write→observe→write feedback loop
Bloom's own writes trigger its own observer. Prevent an infinite loop:
- **On ingest, skip samples authored by Bloom itself:** filter out samples whose `sourceRevision.source == HKSource.default()`. Only ingest *external* sources.
- Never re-write a freshly-ingested value straight back to HealthKit.

## Concurrency (Swift 6 strict)
- `ModelContext` is **not `Sendable`** and is `@MainActor` here — all ingest merges run on the main actor. Make `HealthKitSync` `@MainActor`; `await` HK's async APIs (they suspend off-main and resume back).
- HKHealthStore's classic callback queries call back on an arbitrary queue — hop to `@MainActor` before touching the repository/context. Prefer the modern `async`/descriptor APIs (`requestAuthorization`, `HKAnchoredObjectQueryDescriptor.result(for:)`) which compose with actors cleanly; keep `HKObserverQuery` (still callback-based) thin — hop to main, do the anchored fetch, call `completionHandler()`.

## Entitlements, capability & Info.plist (in `project.yml`)
XcodeGen spec is the source of truth (`.xcodeproj` is generated). Add to the Bloom target:
- **Entitlements** (`Bloom/Bloom.entitlements`):
  - `com.apple.developer.healthkit` = `true`
  - `com.apple.developer.healthkit.background-delivery` = `true` (required for background wake)
  - (leave `com.apple.developer.healthkit.access` unset unless you add clinical record types — Bloom doesn't)
- **Info.plist usage strings** (both mandatory — the app crashes on request without them):
  - `NSHealthShareUsageDescription` (read) and `NSHealthUpdateUsageDescription` (write). In `project.yml` set `INFOPLIST_KEY_NSHealthShareUsageDescription` / `INFOPLIST_KEY_NSHealthUpdateUsageDescription`.
- **Capability:** the HealthKit capability must be enabled on the App ID in the Developer portal and on the target in Xcode (Automatic signing picks it up from the entitlements). No `UIBackgroundModes` entry is needed — HK background delivery is its own mechanism.
- Keep the Stage-4 CloudKit entitlements intact; append HealthKit keys, don't replace.

## The gate (like CloudKit, HK is device-only)
- `#if targetEnvironment(simulator)` / `isHealthDataAvailable()` → HK paths no-op. CI and simulator QA never touch real Health data.
- **Unit-test the pure parts** (the field↔value mapping, cycle-start detection, anchor archive/unarchive round-trip) on any platform — those need no device. Do **not** try to assert real reads/writes in CI.

## On-device verification (Definition of Done — owner runs this)
On a physical iPhone, signed, with the HealthKit capability provisioned:
1. First log → iOS shows the HealthKit permission sheet; grant read+write for the reproductive categories + BBT.
2. **Hers → Health:** log a period (heavy) in Bloom → open **Health ▸ Cycle Tracking** → the period day appears with the right flow; the first day registers a cycle start.
3. **Health → hers:** in the Health app, add a menstrual-flow entry (or a BBT reading) for a day → background/relaunch Bloom → the value appears on that `DailyLog`.
4. **No loop / no dupes:** re-log the same day several times → exactly one sample per type per day in Health (no pile-up); Bloom doesn't re-ingest its own writes.
5. **Denied path:** deny HealthKit at the prompt → app still works fully; no crash; no data leaks.

## Checklist before committing a HealthKit change
- [ ] `isHealthDataAvailable()` guards every entry point; all HK no-ops cleanly on simulator/denied.
- [ ] No branch on `authorizationStatus(for:)` for a read type; prompt decisions use `getRequestStatusForAuthorization`.
- [ ] Mapping table above matches the code exactly; lossy mappings documented.
- [ ] Write-through is idempotent (delete-Bloom-authored-then-insert per day/type); a HK failure never fails the SwiftData save.
- [ ] Ingest filters out `HKSource.default()` (no feedback loop); anchor is persisted and round-trips.
- [ ] Entitlements + both usage strings in `project.yml`; CloudKit entitlements untouched.
- [ ] `@MainActor` respected; no `ModelContext` crossing actors.
- [ ] Pure mapping/anchor logic unit-tested; no CI assertion of real HK I/O.
- [ ] No HealthKit data written into the CloudKit-mirrored store (5.1.3).
