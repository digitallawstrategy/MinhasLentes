import SwiftUI

/// Passo 1 do onboarding: primeira coisa que qualquer pessoa vê ao abrir o app pela primeira
/// vez. Só apresentação — sem nenhum campo, sem nenhuma decisão a tomar — porque o objetivo é o
/// usuário entender em segundos por que o app existe, antes de qualquer pedido de configuração.
struct OnboardingWelcomeStepView: View {
    let onBegin: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                // Mesmo tratamento de "assinatura" que `HomeHeaderView` já usa para o logo: o
                // próprio PNG do ícone do app, com um brilho suave da cor de marca atrás — aqui
                // maior, por ser o elemento central da tela, não um selo ao lado de texto.
                Image("AppLogoAsset")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                    .background(
                        Circle()
                            .fill(AppGradient.primaryButtonBackground)
                            .frame(width: 140, height: 140)
                            .opacity(0.22)
                            .blur(radius: 24)
                    )
                    .accessibilityHidden(true)

                VStack(spacing: AppSpacing.xs) {
                    Text("Minhas Lentes")
                        .font(AppTypography.largeTitle)
                        .multilineTextAlignment(.center)
                    Text("Sua rotina de lentes organizada com calma.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                }
            }
            // Logo, título e subtítulo lidos como uma frase só pelo VoiceOver — o logo em si é
            // decorativo (a marca já está no texto ao lado).
            .accessibilityElement(children: .combine)

            Spacer()
            Spacer()

            PrimaryActionButton(title: "Começar", action: onBegin)
                .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.bottom, AppSpacing.xl)
    }
}

#Preview {
    OnboardingWelcomeStepView(onBegin: {})
        .background(AmbientBackground())
}
