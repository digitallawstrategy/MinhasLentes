import SwiftUI

/// Selo de status compacto — generaliza `UsageStatusBadgeView` para qualquer texto/tom, não só
/// o status de utilização de um par. Nunca depende só da cor: sempre mostra o texto junto.
struct StatusBadge: View {
    let text: String
    var tone: AppStatusTone = .neutral
    var systemImage: String?
    var emoji: String?

    var body: some View {
        Group {
            if let emoji {
                Label {
                    Text(text)
                } icon: {
                    Text(emoji)
                }
            } else if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(AppTypography.captionMedium)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
        .background(tone.color.opacity(0.15), in: Capsule())
        .foregroundStyle(tone.color)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: AppSpacing.sm) {
        StatusBadge(text: "Vida útil alta", tone: .success, emoji: "🟢")
        StatusBadge(text: "Em uso agora", tone: .informative, systemImage: "eye.circle.fill")
        StatusBadge(text: "Estoque baixo", tone: .warning)
    }
    .padding()
}
