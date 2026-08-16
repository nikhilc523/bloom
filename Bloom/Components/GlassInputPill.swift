import SwiftUI

/// A floating input/entry pill — the Ask-Bloom entry or quick log
/// (`design/UI/IMG_4563`, `IMG_4564`: soft floating input bar with round buttons).
/// Gentle pulse on focus. The trailing action is a round DeepRose button.
struct GlassInputPill: View {
    let placeholder: String
    @Binding var text: String
    var trailingIcon: String = "arrow.up"
    var onSubmit: () -> Void

    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text)
                .font(Bloom.Typography.body)
                .foregroundStyle(Bloom.Palette.plumInk)
                .tint(Bloom.Palette.deepRose)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(submit)
                .accessibilityIdentifier("glassInputField")

            Button(action: submit) {
                Image(systemName: trailingIcon)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Bloom.Palette.deepRose))
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
            .opacity(text.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("glassInputSubmit")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: Bloom.Radius.pill)
        .scaleEffect(focused && !reduceMotion ? 1.02 : 1)
        .animation(Bloom.Motion.spring, value: focused)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("glassInputPill")
    }

    private func submit() {
        guard !text.isEmpty else { return }
        Bloom.Haptics.soft()
        onSubmit()
    }
}

#Preview {
    struct Demo: View {
        @State private var text = ""
        var body: some View {
            ZStack {
                Bloom.Background()
                VStack {
                    Spacer()
                    GlassInputPill(placeholder: "Ask Bloom anything…", text: $text) {}
                        .padding()
                }
            }
        }
    }
    return Demo()
}
