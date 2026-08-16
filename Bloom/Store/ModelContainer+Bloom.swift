import Foundation
import SwiftData

/// The single source of truth for Bloom's SwiftData stack. The app and the tests
/// both build their container here, so the production and test schemas can never
/// drift (see `swiftdata-cloudkit-setup` skill).
///
/// **CloudKit posture:** the schema is authored to satisfy every CloudKit
/// private-DB mirroring constraint, but sync is **OFF** (`cloudKitDatabase: .none`)
/// for now. Stage 4 turns it on by changing ONLY that argument to
/// `.private("iCloud.com.nikhilc523.bloom")` and adding the iCloud entitlement —
/// the schema does not change.
enum BloomStore {

    /// Every persisted entity — her private cycle data only. Partner/shared data
    /// is CloudKit-direct and deliberately absent here.
    static let schema = Schema([
        UserEntity.self,
        CycleEntity.self,
        DailyLogEntity.self,
        PredictionEntity.self,
        ClinicalFlagEntity.self,
    ])

    /// Persistent, on-disk store used by the running app. CloudKit-READY, sync OFF.
    static func container() throws -> ModelContainer {
        try makeContainer(inMemory: false)
    }

    /// Isolated in-memory store for unit tests and `-uiTesting`. Never touches
    /// disk or iCloud, so every run starts from a clean, deterministic state.
    static func inMemoryContainer() throws -> ModelContainer {
        try makeContainer(inMemory: true)
    }

    /// Shared builder so both containers use the identical schema + CloudKit posture.
    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            // In-memory stores can't mirror to CloudKit; passing a `cloudKitDatabase`
            // here traps on fetch on-device. Keep the CloudKit posture to the
            // persistent store only.
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Persistent store: CloudKit-READY but sync OFF (`.none`).
            // Stage 4: `.private("iCloud.com.nikhilc523.bloom")`.
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
