import SwiftUI

/// Minimal period-logging sheet. Flow buttons carry stable accessibility
/// identifiers so `ios-ui-automation` / `xcuitest-writer` can drive them.
struct LogSheet: View {
    var onSave: (Flow) -> Void

    @State private var selected: Flow = .medium
    @Environment(\.dismiss) private var dismiss

    private let options: [Flow] = [.light, .medium, .heavy]

    var body: some View {
        ZStack {
            Bloom.Background()

            VStack(spacing: 24) {
                Text("How's your flow today?")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Bloom.Palette.plumInk)

                HStack(spacing: 12) {
                    ForEach(options, id: \.self) { flow in
                        Button {
                            selected = flow
                        } label: {
                            Text(flow.label)
                                .font(.headline)
                                .foregroundStyle(selected == flow ? .white : Bloom.Palette.deepRose)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: Bloom.Radius.md, style: .continuous)
                                        .fill(selected == flow ? Bloom.Palette.deepRose : Bloom.Palette.rose.opacity(0.15))
                                )
                        }
                        .accessibilityIdentifier("flow\(flow.label)Button")
                    }
                }

                Button {
                    onSave(selected)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Bloom.Palette.deepRose))
                }
                .accessibilityIdentifier("saveLogButton")
            }
            .padding(28)
        }
        .presentationDetents([.medium])
    }
}
