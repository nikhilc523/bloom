import SwiftUI
import UIKit

@main
struct BloomApp: App {
    init() {
        if CommandLine.arguments.contains("-uiTesting") {
            // Deterministic UI-test mode: in-memory state, no CloudKit/HealthKit.
            // (Wire real in-memory ModelContainer here once SwiftData lands.)
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
