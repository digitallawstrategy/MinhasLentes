import SwiftUI

/// Passo 4 (último) do onboarding: explica com calma por que o app pede notificações antes de
/// de fato chamar o sistema — `onContinue` dispara a autorização real, `onSkip` conclui o
/// onboarding sem pedir nada. Nenhum dos dois bloqueia a conclusão: ver `OnboardingView`, que
/// sempre marca o onboarding como concluído depois de qualquer uma das duas escolhas.
struct NotificationPermissionView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        // Mesmo padrão `GeometryReader` + `ScrollView` dos outros 3 passos (ver comentário em
        // `OnboardingWelcomeStepView`) — este passo é o que tem mais conteúdo (título + subtítulo
        // + 3 linhas de benefício + 2 botões), o mais propenso a ultrapassar a tela em Dynamic
        // Type grande.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    Spacer(minLength: AppSpacing.xxl)

                    VStack(spacing: AppSpacing.lg) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 44))
                            .foregroundStyle(AppColor.primary)
                            .frame(width: 88, height: 88)
                            .background(AppColor.primary.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)

                        VStack(spacing: AppSpacing.xs) {
                            Text("Fique de olho, sem esforço")
                                .font(AppTypography.title)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Avisamos só quando importa:")
                                .font(AppTypography.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    VStack(spacing: AppSpacing.md) {
                        OnboardingFeatureRow(systemImage: "sparkles", title: "Lembretes de limpeza do estojo")
                        OnboardingFeatureRow(systemImage: "clock.badge.exclamationmark", title: "Avisos de tempo de uso prolongado")
                        OnboardingFeatureRow(systemImage: "arrow.triangle.2.circlepath", title: "Troca de estojo e solução")
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    Spacer(minLength: AppSpacing.xxl)

                    VStack(spacing: AppSpacing.sm) {
                        PrimaryActionButton(title: "Permitir notificações", action: onContinue)
                        SecondaryActionButton(title: "Agora não", action: onSkip)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.xl)
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}

#Preview {
    NotificationPermissionView(onContinue: {}, onSkip: {})
        .background(AmbientBackground())
}
