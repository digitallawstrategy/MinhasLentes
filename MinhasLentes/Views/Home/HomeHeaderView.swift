import SwiftUI

/// Cabeçalho do Início: marca + saudação, no lugar da barra de navegação padrão — a saudação já
/// cumpre o papel de título de tela, então a navigation bar nativa ficaria redundante aqui (nas
/// outras abas ela continua normal). O sino leva às notificações em Ajustes (Mais → Notificações),
/// o único lugar real relacionado a avisos que o app tem — sem badge de "não lidas": o app não
/// guarda esse conceito, e um indicador que não corresponde a nada real seria decoração enganosa.
struct HomeHeaderView: View {
    let greeting: String
    let subtitle: String
    let onNotificationsTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    AppLogoMark(size: 26)
                    Text("Minhas Lentes")
                        .font(AppTypography.headline)
                        .foregroundStyle(.secondary)
                }
                Text(greeting)
                    .font(AppTypography.title)
                Text(subtitle)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button(action: onNotificationsTap) {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(AppColor.surfaceElevated, in: Circle())
            }
            .buttonStyle(.plain)
            .pressScale()
            .accessibilityLabel("Notificações")
            .accessibilityHint("Abre as configurações de notificações")
        }
    }
}

#Preview {
    HomeHeaderView(greeting: "Boa tarde", subtitle: "Vamos cuidar bem das suas lentes hoje.", onNotificationsTap: {})
        .padding()
}
