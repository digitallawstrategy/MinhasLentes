import SwiftUI

/// Aviso discreto — ícone + texto curto num fundo levemente tingido — para orientações que
/// precisam existir mas não devem abrir/dominar a tela como um disclaimer (ex.: "este app não
/// substitui orientação médica" no topo de Consultas). Sempre tom + ícone + texto juntos, nunca
/// só cor, como todo componente de status deste design system.
struct InfoBanner: View {
    var systemImage: String = "info.circle"
    let text: String
    var tone: AppStatusTone = .informative

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(tone.color)
                .accessibilityHidden(true)
            Text(text)
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.color.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: AppSpacing.sm) {
        InfoBanner(text: "Siga sempre a recomendação do seu oftalmologista. Este aplicativo não sugere diagnóstico — apenas ajuda a acompanhar contatos e prazos.")
        InfoBanner(systemImage: "exclamationmark.triangle", text: "1 item vencido no estoque.", tone: .warning)
    }
    .padding()
}
