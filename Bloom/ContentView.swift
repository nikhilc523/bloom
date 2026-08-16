import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var cycleDay = 5
    private let cycleLength = 28
    @State private var showingLog = false
    @State private var loggedToday = false

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
    }

    /// Persist today's flow through the repository so it survives relaunch.
    /// (UI may read the wall clock — the purity rule applies to the engines, not here.)
    private func persistTodaysFlow(_ flow: Flow) {
        let repository = SwiftDataRepository(context: modelContext)
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
