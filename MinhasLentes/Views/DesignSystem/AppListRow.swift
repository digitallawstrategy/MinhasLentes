import SwiftUI

/// Linha de lista com composição própria — ícone num selo colorido, título/subtítulo, e um
/// valor/status à direita — para as listas operacionais (Estoque, Solução) que continuam em
/// `List` nativa (correta para swipe actions e edição em lote), mas que hoje têm todo texto com
/// o mesmo peso visual. Não é um `Button`/`NavigationLink` por padrão: a maioria dos usos aqui é
/// dentro de uma `List` com `.swipeActions`, não navegação — quem precisar de toque usa esta
/// view como conteúdo de um `Button`/`NavigationLink` por fora, do jeito que `ReminderCard` já
/// faz para o caso de cartões tocáveis.
struct AppListRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var systemImage: String?
    /// Sobrepõe `systemImage` quando presente — o único caso hoje é a foto opcional de um item
    /// de estoque. Sempre a mesma moldura do selo de ícone, para não quebrar o alinhamento das
    /// linhas vizinhas que não têm foto.
    var leadingImage: UIImage?
    var tone: AppStatusTone = .neutral
    let title: String
    var subtitle: String?
    var trailingText: String?
    var trailingTone: AppStatusTone?

    var body: some View {
        // Em tamanhos padrão, título/subtítulo e o valor à direita dividem a mesma linha — cabe
        // uma data ou status curto sem quebrar. Em accessibility sizes essa mesma linha não cabe
        // mais os dois lados: o valor à direita (data, "X de Y unidade(s)") quebrava no meio do
        // texto ("28/01/202" / "7") tentando se espremer numa coluna estreita. Em vez de encolher
        // a fonte para esconder isso, o valor desce para uma linha própria, abaixo do título,
        // alinhado à esquerda como o resto do bloco de texto — mesmo padrão de
        // `FeaturedReminderRow`/`MetricStrip` para este limiar.
        if dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                leadingIcon
                VStack(alignment: .leading, spacing: 2) {
                    titleBlock
                    if trailingText != nil {
                        trailingLabel
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, AppSpacing.xxs)
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: AppSpacing.sm) {
                leadingIcon
                titleBlock
                Spacer(minLength: AppSpacing.xs)
                trailingLabel
            }
            .padding(.vertical, AppSpacing.xxs)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if let leadingImage {
            Image(uiImage: leadingImage)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                .accessibilityHidden(true)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tone.color)
                .frame(width: 36, height: 36)
                .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.subheadlineMedium)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Nunca quebra: uma data ou status é lido de relance, não em duas linhas fragmentadas no
    // meio de um número. Se não couber mesmo numa linha própria, o próprio layout já resolve.
    @ViewBuilder
    private var trailingLabel: some View {
        if let trailingText {
            Text(trailingText)
                .font(AppTypography.captionMedium)
                .foregroundStyle(trailingTone?.color ?? .secondary)
                .lineLimit(1)
        }
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
