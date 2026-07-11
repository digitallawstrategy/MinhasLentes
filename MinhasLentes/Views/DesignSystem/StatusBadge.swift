import SwiftUI

/// Selo de status compacto — texto e tom livres, usado tanto para o status de utilização de um
/// par quanto para qualquer outro selo do app. Nunca depende só da cor: sempre mostra o texto
/// junto.
struct StatusBadge: View {
    let text: String
    var tone: AppStatusTone = .neutral
    var systemImage: String?
    var emoji: String?
    /// Quando o selo divide uma linha com um botão de peso equivalente (ex.: "Uso registrado
    /// hoje" ao lado de "Retirei as lentes") — sem isto, o selo fica compacto de propósito, do
    /// tamanho do próprio texto, como em todo o resto do app.
    var fullWidth: Bool = false

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
        .font(AppTypography.badge)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, fullWidth ? AppSpacing.xs : AppSpacing.xxs)
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
