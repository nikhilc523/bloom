import SwiftUI
import SwiftData
import UIKit

@main
struct BloomApp: App {
    /// The SwiftData stack for the whole app. `-uiTesting` gets an isolated
    /// in-memory store (deterministic, no disk/iCloud); everything else gets the
    /// persistent, CloudKit-ready store (sync OFF until Stage 4).
    private let container: ModelContainer

    init() {
        let uiTesting = CommandLine.arguments.contains("-uiTesting")
        if uiTesting {
            UIView.setAnimationsEnabled(false)
        }
        do {
            container = try uiTesting ? BloomStore.inMemoryContainer() : BloomStore.container()
        } catch {
            // A store that can't open is unrecoverable — fail loud rather than
            // silently drop to a throwaway store and lose her data.
            fatalError("Failed to create Bloom ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // Dev-only design-system catalog, reachable ONLY when launched with
            // `-designGallery` (and only in DEBUG builds). Never in the real app.
            if CommandLine.arguments.contains("-designGallery") {
                DesignGallery()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
        .modelContainer(container)
    }
}
