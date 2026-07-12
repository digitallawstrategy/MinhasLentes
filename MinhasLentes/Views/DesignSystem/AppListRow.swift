import SwiftUI

/// Linha de lista com composição própria — ícone num selo colorido, título/subtítulo, e um
/// valor/status à direita — para as listas operacionais (Estoque, Solução) que continuam em
/// `List` nativa (correta para swipe actions e edição em lote), mas que hoje têm todo texto com
/// o mesmo peso visual. Não é um `Button`/`NavigationLink` por padrão: a maioria dos usos aqui é
/// dentro de uma `List` com `.swipeActions`, não navegação — quem precisar de toque usa esta
/// view como conteúdo de um `Button`/`NavigationLink` por fora, do jeito que `ReminderCard` já
/// faz para o caso de cartões tocáveis.
struct AppListRow: View {
    var systemImage: String?
    var tone: AppStatusTone = .neutral
    let title: String
    var subtitle: String?
    var trailingText: String?
    var trailingTone: AppStatusTone?

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(tone.color)
                    .frame(width: 36, height: 36)
                    .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.subheadlineMedium)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: AppSpacing.xs)
            if let trailingText {
                Text(trailingText)
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(trailingTone?.color ?? .secondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AppSpacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        AppListRow(
            systemImage: "eyeglasses",
            tone: .success,
            title: "Acme — Diária Plus",
            subtitle: "Ambos os olhos · 8 de 10 restantes",
            trailingText: "Válida",
            trailingTone: .success
        )
        AppListRow(
            systemImage: "eyeglasses",
            tone: .warning,
            title: "Acme — Diária Plus",
            subtitle: "Olho direito · 1 de 10 restantes",
            trailingText: "Vence em 5d",
            trailingTone: .warning
        )
    }
}
