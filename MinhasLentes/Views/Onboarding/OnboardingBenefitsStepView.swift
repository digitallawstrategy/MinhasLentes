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
        // `.frame(maxWidth: .infinity, alignment: .leading)` no lugar de um `Spacer` à direita:
        // com um `Spacer`, `Text`/`Spacer` disputam o espaço flexível com a mesma prioridade e o
        // `Text` acaba truncado em vez de quebrar linha em Dynamic Type grande (confirmado em
        // accessibility XXXL) — `.frame` já reserva o espaço restante direto para o texto, sem
        // disputa. `alignment: .top` no `HStack` (não `.center`, o padrão) para o selo do ícone
        // ficar alinhado ao topo quando o texto quebra em 2+ linhas.
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppColor.primary)
                .frame(width: 44, height: 44)
                .background(AppColor.primary.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(AppTypography.subheadlineMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
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
        // `ScrollView` + `GeometryReader` (para o conteúdo saber a altura real disponível e
        // preencher via `minHeight:`), não uma pilha fixa com `Spacer`s soltos: em Dynamic Type
        // grande (accessibility XXXL) o título + 3 linhas de benefício facilmente ultrapassam a
        // altura da tela — sem rolagem, o SwiftUI comprime tudo pra caber, e essa compressão
        // vertical trunca o texto em vez de simplesmente rolar (confirmado visualmente). Com
        // `minHeight: proxy.size.height`, em tamanho padrão o conteúdo ainda ocupa a tela cheia e
        // os `Spacer`s centralizam normalmente — só em Dynamic Type grande é que ultrapassa essa
        // altura mínima e passa a rolar.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    Spacer(minLength: AppSpacing.xxl)

                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        Text("Como o Minhas Lentes ajuda")
                            .font(AppTypography.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: AppSpacing.md) {
                            OnboardingFeatureRow(systemImage: "eye", title: "Acompanhe os usos das lentes")
                            OnboardingFeatureRow(systemImage: "heart.text.square", title: "Cuide do estojo e da solução")
                            OnboardingFeatureRow(systemImage: "bell", title: "Receba lembretes no momento certo")
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    Spacer(minLength: AppSpacing.xxl)

                    PrimaryActionButton(title: "Continuar", action: onContinue)
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.xl)
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}

#Preview {
    OnboardingBenefitsStepView(onContinue: {})
        .background(AmbientBackground())
}
