import SwiftUI

struct ContentView: View {
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
            LogSheet { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    loggedToday = true
                }
                showingLog = false
            }
        }
    }
}

#Preview {
    ContentView()
}
