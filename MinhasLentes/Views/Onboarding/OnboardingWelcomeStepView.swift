import SwiftUI

/// Passo 1 do onboarding: primeira coisa que qualquer pessoa vê ao abrir o app pela primeira
/// vez. Só apresentação — sem nenhum campo, sem nenhuma decisão a tomar — porque o objetivo é o
/// usuário entender em segundos por que o app existe, antes de qualquer pedido de configuração.
struct OnboardingWelcomeStepView: View {
    let onBegin: () -> Void

    var body: some View {
        // `ScrollView` + `GeometryReader`, não uma pilha fixa: sem largura/altura reservadas
        // explicitamente, o título em `largeTitle` (maior fonte do app) chegava a ultrapassar as
        // bordas da tela em Dynamic Type "Accessibility XXXL" em vez de quebrar linha — texto sem
        // nenhum `Spacer`/`Text` vizinho competindo por espaço não recebe uma largura proposta
        // finita da forma como `VStack` propaga por padrão; `.frame(maxWidth: .infinity)` no
        // título resolve isso de vez, e o `ScrollView` garante que, mesmo quebrando em várias
        // linhas, o conteúdo role em vez de ser cortado.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    Spacer(minLength: AppSpacing.xxl)

                    VStack(spacing: AppSpacing.lg) {
                        // Mesmo tratamento de "assinatura" que `HomeHeaderView` já usa para o
                        // logo: o próprio PNG do ícone do app, com um brilho suave da cor de
                        // marca atrás — aqui maior, por ser o elemento central da tela, não um
                        // selo ao lado de texto.
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
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Sua rotina de lentes organizada com calma.")
                                .font(AppTypography.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    // Logo, título e subtítulo lidos como uma frase só pelo VoiceOver — o logo
                    // em si é decorativo (a marca já está no texto ao lado).
                    .accessibilityElement(children: .combine)

                    Spacer(minLength: AppSpacing.xxl)

                    PrimaryActionButton(title: "Começar", action: onBegin)
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.xl)
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}

#Preview {
    OnboardingWelcomeStepView(onBegin: {})
        .background(AmbientBackground())
}
