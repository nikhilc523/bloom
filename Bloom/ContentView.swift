import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var cycleDay = 5
    private let cycleLength = 28
    @State private var showingLog = false
    @State private var loggedToday = false

    /// The HealthKit two-way sync (Stage 5). Built once on appear from the main
    /// context; nil until then and a no-op wherever HealthKit is unavailable
    /// (Simulator / iPad / denied), so nothing here depends on a device.
    @State private var healthKit: HealthKitSync?

    var body: some View {
        ZStack {
            Bloom.Background()

            VStack(spacing: 28) {
                Text("Bloom")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Bloom.Palette.deepRose)

                CycleRing(day: cycleDay, length: cycleLength)

                if loggedToday {
                    GlassCard {
                        Label("Logged today", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Bloom.Palette.deepRose)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("loggedTodayBadge")
                    .transition(.scale.combined(with: .opacity))
                }

                Button {
                    showingLog = true
                } label: {
                    Text("Log Period")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(Bloom.Palette.deepRose)
                        )
                }
                .accessibilityIdentifier("logPeriodButton")
            }
            .padding()
        }
        .sheet(isPresented: $showingLog) {
            LogSheet { flow in
                persistTodaysFlow(flow)
                showingLog = false
            }
        }
        .onAppear(perform: refreshLoggedToday)
        .task { await startHealthKit() }
    }

    /// Persist today's flow through the repository so it survives relaunch, and
    /// (on device) mirror it to Apple Health via the HealthKit-mirroring wrapper.
    /// (UI may read the wall clock — the purity rule applies to the engines, not here.)
    private func persistTodaysFlow(_ flow: Flow) {
        let repository = logRepository()
        let today = Calendar.current.startOfDay(for: Date())
        do {
            var log = try repository.log(on: today) ?? DailyLog(date: today)
            log.flow = flow
            try repository.upsert(log)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                loggedToday = true
            }
        } catch {
            // Persistence failed — leave the badge off rather than fake success.
            assertionFailure("Failed to persist daily log: \(error)")
        }
    }

    /// The write path: mirror to HealthKit when the sync is live, otherwise the
    /// plain store. Reads/refresh can use the plain repository directly.
    private func logRepository() -> any LogRepository {
        let base = SwiftDataRepository(context: modelContext)
        guard let healthKit else { return base }
        return HealthKitMirroringLogRepository(base: base, sync: healthKit)
    }

    /// Build the HealthKit sync once, request authorization, and begin observing
    /// external Health changes. No-ops off-device; safe to call every appear.
    private func startHealthKit() async {
        guard healthKit == nil else { return }
        let base = SwiftDataRepository(context: modelContext)
        let sync = HealthKitSync(logRepository: base)
        healthKit = sync
        await sync.requestAuthorization()
        await sync.startObserving()
    }

    /// Reflect persisted state on launch: badge shows if today already has a log.
    private func refreshLoggedToday() {
        let repository = SwiftDataRepository(context: modelContext)
        let today = Calendar.current.startOfDay(for: Date())
        let existing = (try? repository.log(on: today)) ?? nil
        loggedToday = existing != nil
    }
}

#Preview {
    ContentView()
}
