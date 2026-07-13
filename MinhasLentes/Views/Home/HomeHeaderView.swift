import SwiftUI

/// Cabeçalho do Início: marca + saudação, no lugar da barra de navegação padrão — a saudação já
/// cumpre o papel de título de tela, então a navigation bar nativa ficaria redundante aqui (nas
/// outras abas ela continua normal). O sino abre a central de avisos (`NotificationsCenterView`,
/// pendências reais do app) — nunca um atalho para Configurações. O badge só aparece quando há
/// pendência de verdade (`hasPendingItems`), nunca como decoração sem correspondência real.
struct HomeHeaderView: View {
    let greeting: String
    let subtitle: String
    var hasPendingItems: Bool = false
    let onNotificationsTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    // O mesmo PNG do ícone do app (Assets.xcassets/AppIcon.appiconset),
                    // duplicado num imageset comum — um "AppIcon.appiconset" não é acessível via
                    // Image(_:) de forma confiável, e a marca no cabeçalho precisa ser
                    // literalmente a mesma arte do ícone, não um desenho à parte tentando lembrá-la.
                    // Um brilho suave atrás (mesmo tom da marca) dá peso de assinatura ao ícone,
                    // em vez de um selo pequeno e tímido perdido ao lado do texto.
                    Image("AppLogoAsset")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .background(
                            Circle()
                                .fill(AppGradient.primaryButtonBackground)
                                .frame(width: 46, height: 46)
                                .opacity(0.22)
                                .blur(radius: 10)
                        )
                        .accessibilityHidden(true)
                    Text("Minhas Lentes")
                        .font(AppTypography.headline)
                        .foregroundStyle(.secondary)
                }
                // Gradiente da marca (o mesmo do botão primário) em vez da cor padrão do texto —
                // a saudação é o elemento mais lido da tela, então é ela que carrega a
                // identidade, não um selo decorativo à parte.
                Text(greeting)
                    .font(AppTypography.title)
                    .foregroundStyle(AppGradient.primaryButtonBackground)
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
                    .overlay(alignment: .topTrailing) {
                        if hasPendingItems {
                            Circle()
                                .fill(AppColor.warning)
                                .frame(width: 10, height: 10)
                                .offset(x: -2, y: 2)
                        }
                    }
            }
            .buttonStyle(.plain)
            .pressScale()
            .accessibilityLabel("Avisos")
            .accessibilityHint("Abre os avisos pendentes")
            .accessibilityValue(hasPendingItems ? "Há pendências" : "Tudo em dia")
        }
    }
}

#Preview {
    HomeHeaderView(greeting: "Boa tarde", subtitle: "Vamos cuidar bem das suas lentes hoje.", onNotificationsTap: {})
        .padding()
}
