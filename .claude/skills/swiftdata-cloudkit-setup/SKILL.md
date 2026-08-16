---
name: swiftdata-cloudkit-setup
description: Set up Bloom's SwiftData persistence so it is CloudKit-private-DB-ready — @Model schema that satisfies every CloudKit-mirroring constraint, a ModelContainer factory (persistent + in-memory), and the private-store/partner-zone separation. Use when adding or changing persisted models, the container, or the repository, or when preparing for CloudKit sync (Stage 4).
---

# SwiftData + CloudKit setup (Bloom)

How Bloom persists **her private cycle data** (User, Cycle, DailyLog, Prediction, ClinicalFlag) in SwiftData, configured so that turning on CloudKit private-DB sync in Stage 4 is a one-line change — not a schema migration. Grounded in Apple's SwiftData/CloudKit guidance and this app's data-model doc (`docs/product/01-data-model.md` §Storage split → `docs/research/04-apple-tech.md`).

**Golden rule for this app:** the SwiftData store holds **only her private data**. The partner shared layer (SharedState, PinnedNote) is **CloudKit custom zone + CKShare, direct — never SwiftData** (SwiftData can't use the shared/public DB). Keep the two stores separate. Any code that writes partner data into this container is a P0 bug.

## CloudKit-mirroring constraints — every one is mandatory
When a `ModelContainer` mirrors to CloudKit, the schema is validated against CloudKit's rules. Violate one and the store **fails to load at runtime** (or silently never syncs). Design for these from day one even while sync is OFF:

1. **Every stored property is optional or has a default value.** CloudKit records have no non-null guarantee. `var flowRaw: String? ` or `var isPredicted: Bool = false` — never a non-optional, non-defaulted stored property.
2. **No `@Attribute(.unique)`.** Unique constraints are unsupported with CloudKit mirroring. Enforce identity/uniqueness in the **repository** (fetch-then-update), not the schema.
3. **All relationships optional, and inverses defined.** No required (non-optional) relationships; every `@Relationship` needs its inverse. (Bloom currently uses no cross-entity relationships — entities are flat + a Codable payload — so this is trivially satisfied; keep it that way unless there's a real need.)
4. **No `.unique` / no `.deny` delete rules that CloudKit can't express.** Prefer `.cascade`/`.nullify`.
5. **The CloudKit container entitlement + background modes** are required only when sync is actually enabled (Stage 4). Do not add the entitlement now — it triggers App Store review requirements early.

## The container factory pattern
Provide ONE factory, used by the app and tests, so prod and test schemas can never drift.

```swift
enum BloomStore {
    static let schema = Schema([
        UserEntity.self, CycleEntity.self, DailyLogEntity.self,
        PredictionEntity.self, ClinicalFlagEntity.self,
    ])

    /// Persistent, on-disk store. CloudKit-READY but sync OFF (`.none`) for now.
    /// Stage 4 flips `.none` → `.private("iCloud.com.nikhilc523.bloom")` + entitlement.
    static func container() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema,
                                        isStoredInMemoryOnly: false,
                                        cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// In-memory store for tests and `-uiTesting`. Never touches disk or iCloud.
    static func inMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema,
                                        isStoredInMemoryOnly: true,
                                        cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }
}
```

- `cloudKitDatabase: .none` keeps sync OFF while the schema is still validated for CloudKit-readiness in review. When Stage 4 lands, change ONLY that argument (and add the entitlement) — the schema does not change.
- Tests and `-uiTesting` must use `inMemoryContainer()` — deterministic, isolated, no disk residue.

## Concurrency (Swift 6 strict) — the thing that will bite you
`ModelContext` and `ModelContainer`'s contexts are **not `Sendable`**. Do not pass a context across actors or capture it in a detached `Task`.
- Keep the repository `@MainActor` and do reads/writes on the main context, **or** use a dedicated `@ModelActor` for background work — never share one context across both.
- SwiftUI: inject with `.modelContainer(container)`; views read via `@Query` / `@Environment(\.modelContext)` on the main actor.

## Mapping strategy (pure value types ⇄ @Model)
Stage 1 keeps the domain as pure, `Codable`, `Sendable` value types (logic never touches SwiftData). Storage is a **thin mapping**:
- Each `@Model` stores the domain object as a **Codable payload** (`Data`) — the authoritative copy — plus a few **optional/defaulted scalar columns** (id, date, startDate, isPredicted, createdAt, dismissed, type) used only for `#Predicate` filtering and sorting.
- The payload is the single source of truth; scalar columns are **derived on write**. `toDomain()` decodes only the payload. This makes the round-trip test (`encode → store → fetch → decode → ==`) prove fidelity, and keeps the CloudKit surface to `Data?` + optional scalars.
- Trade-off: blob storage means CloudKit merges per-record (last-writer-wins), not per-field. For a single owner's private data across her own devices that's acceptable and matches SwiftData+CloudKit's record-level granularity. Revisit only if a real field-level-merge need appears.

## Migrations
- Wrap schema evolution in a `SchemaMigrationPlan` with explicit `VersionedSchema` stages; never mutate a shipped schema in place.
- Adding an **optional** column or a new entity = lightweight migration (safe). Renames/type-changes/required columns = a custom stage with a migration test against a store seeded with the old version. A schema change with **no migration plan** against existing on-device data is a P0 (data loss on update).
- Because the domain lives in the Codable payload, most field additions are absorbed by the payload without a SwiftData migration at all — but bump the versioned schema when you add/rename a **scalar column**.

## Checklist before you commit a model change
- [ ] Every new stored property optional or defaulted; no `@Attribute(.unique)`.
- [ ] Schema registered in `BloomStore.schema` (both containers share it).
- [ ] Repository stays `@MainActor` (or `@ModelActor`); no `ModelContext` crossing actors.
- [ ] Round-trip test on the in-memory container; relaunch-survival test on a temp on-disk store.
- [ ] No partner/shared data in this container.
- [ ] If a scalar column changed: versioned schema bumped + migration test.
