import Foundation
import SwiftData

/// The single source of truth for Bloom's SwiftData stack. The app and the tests
/// both build their container here, so the production and test schemas can never
/// drift (see `swiftdata-cloudkit-setup` skill).
///
/// **CloudKit posture (Stage 4):** the persistent store mirrors to her **private**
/// CloudKit database (`cloudKitDatabase: .private(cloudKitContainerID)`). The
/// schema — authored in Stage 3 to satisfy every CloudKit mirroring constraint
/// (all properties optional/defaulted, no `@Attribute(.unique)`, no relationships)
/// — is unchanged. The in-memory store (tests / `-uiTesting`) stays local-only.
/// Requires the iCloud/CloudKit entitlement in `Bloom/Bloom.entitlements`.
enum BloomStore {

    /// The iCloud CloudKit container that mirrors her private store. This string
    /// MUST match `com.apple.developer.icloud-container-identifiers` in
    /// `Bloom/Bloom.entitlements` and the container provisioned in the Apple
    /// Developer portal — a mismatch means the store opens locally but never syncs.
    static let cloudKitContainerID = "iCloud.com.nikhilc523.bloom"

    /// Every persisted entity — her private cycle data only. Partner/shared data
    /// is CloudKit-direct and deliberately absent here.
    static let schema = Schema([
        UserEntity.self,
        CycleEntity.self,
        DailyLogEntity.self,
        PredictionEntity.self,
        ClinicalFlagEntity.self,
    ])

    /// Whether this build enables CloudKit private-DB mirroring.
    ///
    /// This gate is **mandatory**, not defensive: SwiftData's CloudKit mirroring
    /// configures itself *asynchronously after the container init returns*, and
    /// when the iCloud entitlement is absent it **traps the whole process** (the
    /// "BUG IN CLIENT OF CLOUDKIT" assertion) — not a catchable `throw`, so we
    /// must decide before ever asking for `.private(...)`.
    ///
    /// The honest axis is *signed device* vs *not*. Every simulator path in this
    /// project is unsigned — CI (`CODE_SIGNING_ALLOWED=NO`) and local QA via
    /// `ios-build-run` — so it carries no entitlement and must stay local-only.
    /// Device builds are signed in Xcode (team + iCloud capability that provisions
    /// the container) and get real sync. Same on-disk store either way; the
    /// simulator simply omits the cloud mirror, so nothing is lost. This matches
    /// the Stage-4 DoD: cross-device sync is validated manually on device.
    #if targetEnvironment(simulator)
    static let cloudKitEnabled = false
    #else
    static let cloudKitEnabled = true
    #endif

    /// Persistent, on-disk store used by the running app. On device, CloudKit
    /// private-DB sync is ON — writes mirror to her iCloud and fan out to her
    /// other signed-in devices. Works fully offline: the local store is always
    /// authoritative and SwiftData reconciles with CloudKit when connectivity
    /// (and an iCloud account) return.
    static func container() throws -> ModelContainer {
        try makeContainer(inMemory: false, cloudKit: cloudKitEnabled)
    }

    /// Isolated in-memory store for unit tests and `-uiTesting`. Never touches
    /// disk or iCloud, so every run starts from a clean, deterministic state.
    static func inMemoryContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true, cloudKit: false)
    }

    /// Shared builder so every container uses the identical schema. `cloudKit`
    /// selects the persistent store's mirroring posture; in-memory stores are
    /// always local-only (passing a `cloudKitDatabase` to one traps on fetch).
    static func makeContainer(inMemory: Bool, cloudKit: Bool) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Persistent store. With CloudKit ON, SwiftData mirrors every record
            // to the private database of `cloudKitContainerID`; conflicts resolve
            // last-writer-wins per record (Stage 3 handoff: blob payload →
            // record-level merge, fine for one owner across her own devices).
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: cloudKit ? .private(cloudKitContainerID) : .none
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
