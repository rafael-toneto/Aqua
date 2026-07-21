import SwiftUI

struct AquaCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AquaSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: AquaCornerRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: AquaCornerRadius.card)
                    .stroke(.separator.opacity(0.35), lineWidth: 0.5)
            }
    }
}

struct AquaErrorMessage: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Error: \(message)")
    }
}
