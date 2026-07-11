import SwiftUI

/// Cabeçalho do Início: marca + saudação, no lugar da barra de navegação padrão — a saudação já
/// cumpre o papel de título de tela, então a navigation bar nativa ficaria redundante aqui (nas
/// outras abas ela continua normal). Sem sino/notificações: o app não tem uma caixa de entrada de
/// avisos, só notificações do sistema, e um ícone que não abre nada seria decoração enganosa.
struct HomeHeaderView: View {
    let greeting: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                AppLogoMark(size: 18)
                Text("Minhas Lentes")
                    .font(AppTypography.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(greeting)
                .font(AppTypography.title)
            Text(subtitle)
                .font(AppTypography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeHeaderView(greeting: "Boa tarde", subtitle: "Vamos cuidar bem das suas lentes hoje.")
        .padding()
}
