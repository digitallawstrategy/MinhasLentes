import SwiftUI

/// Linha "ícone em selo + rótulo curto" — compartilhada pelo passo de benefícios (aqui) e pelo
/// passo de notificações (`NotificationPermissionView`), as duas telas do onboarding que mostram
/// essa mesma forma. Não é `AppListRow`: aquele componente é documentado como específico de
/// listas operacionais densas com swipe actions/valor à direita (`AppListRow.swift`), papel
/// diferente deste — aqui não há lista, nem valor à direita, só uma frase por linha.
struct OnboardingFeatureRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppColor.primary)
                .frame(width: 44, height: 44)
                .background(AppColor.primary.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(AppTypography.subheadlineMedium)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Passo 2 do onboarding: 3 benefícios concretos, com o mesmo vocabulário de ícone que as abas
/// principais já usam para os mesmos conceitos (`eye` = aba Lentes, `heart.text.square` = aba
/// Cuidados, `bell` = o sino da Home) — reforça o mesmo mapa mental em vez de introduzir ícones
/// novos para as mesmas ideias.
struct OnboardingBenefitsStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Como o Minhas Lentes ajuda")
                    .font(AppTypography.title)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: AppSpacing.md) {
                    OnboardingFeatureRow(systemImage: "eye", title: "Acompanhe os usos das lentes")
                    OnboardingFeatureRow(systemImage: "heart.text.square", title: "Cuide do estojo e da solução")
                    OnboardingFeatureRow(systemImage: "bell", title: "Receba lembretes no momento certo")
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
            Spacer()

            PrimaryActionButton(title: "Continuar", action: onContinue)
                .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.bottom, AppSpacing.xl)
    }
}

#Preview {
    OnboardingBenefitsStepView(onContinue: {})
        .background(AmbientBackground())
}
