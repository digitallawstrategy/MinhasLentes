import SwiftUI

/// Passo 3 do onboarding: mesma lógica/campos do formulário original (data de início, limite de
/// usos, modo de controle, última limpeza do estojo), redesenhados em `AppCard` dentro de um
/// `ScrollView` em vez de `Form`/`Section` nativos — "menos formulário bruto, mais fluxo guiado",
/// mantendo os mesmos controles nativos (`DatePicker`/`Stepper`/`Picker`) e o mesmo binding direto
/// com `OnboardingViewModel` de antes.
struct OnboardingSetupStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        // `GeometryReader` em volta do `ScrollView`: sem ele, o `ScrollView` propunha altura
        // irrestrita mas a compressão vertical (sem rolagem) ainda truncava texto em Dynamic Type
        // grande antes de existir rolagem — mesmo padrão usado nos outros 3 passos.
        GeometryReader { proxy in
            ScrollView {
                // `.frame(maxWidth: proxy.size.width)` logo abaixo (depois do `.padding`, com
                // `alignment: .leading`): o `DatePicker` (estilo compacto) é um botão de largura
                // rígida que mostra
                // a data por extenso ("14 de julho de 2026") — em Dynamic Type "Accessibility
                // XXXL" esse texto sozinho pode legitimamente ultrapassar a largura da tela, e sem
                // um teto duro aqui, esse único filho "empurrava" a largura de TODO o `VStack`
                // (irmãos incluídos, como o título) para além da tela — mesmo o título já tendo
                // seu próprio `.frame(maxWidth: .infinity)`. Com o teto aqui, o título volta a
                // quebrar linha corretamente; o próprio botão do `DatePicker`, que não tem como
                // quebrar linha (é um controle nativo, não um `Text`), pode cortar o final da data
                // nesse tamanho extremo — limitação conhecida do controle do sistema, não deste
                // layout (o mesmo acontece em apps da própria Apple em Dynamic Type extremo).
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Vamos configurar seu par")
                            .font(AppTypography.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Você pode ajustar tudo isso depois, a qualquer momento.")
                            .font(AppTypography.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    AppCard {
                        Text("Novo par de lentes")
                            .font(AppTypography.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        labeledField("Data de início") {
                            DatePicker("Data de início", selection: $viewModel.startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        labeledField("Limite de usos: \(viewModel.maximumUses)") {
                            Stepper("Limite de usos", value: $viewModel.maximumUses, in: 1...500)
                                .labelsHidden()
                        }
                        labeledField("Modo de controle") {
                            Picker("Modo de controle", selection: $viewModel.trackingMode) {
                                ForEach(TrackingMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    AppCard {
                        Text("Estojo")
                            .font(AppTypography.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        labeledField("Última limpeza registrada") {
                            DatePicker("Última limpeza registrada", selection: $viewModel.lastCleaningDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }

                    PrimaryActionButton(title: "Continuar", isDisabled: viewModel.isCompleting, action: onContinue)
                        .overlay {
                            if viewModel.isCompleting {
                                ProgressView().tint(.white)
                            }
                        }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: proxy.size.width, alignment: .leading)
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// Rótulo em cima, controle embaixo — não lado a lado, como o `DatePicker`/`Stepper`/`Picker`
    /// nativos fariam por padrão fora de um `Form`. Lado a lado, rótulo e controle disputam a
    /// mesma linha; nenhum dos dois é um `Text` comum que aceita ser espremido/quebrar linha (são
    /// controles nativos, de largura rígida), então em Dynamic Type "Accessibility XXXL" a soma
    /// dos dois ultrapassava a largura da tela (confirmado visualmente). Empilhados, cada um usa
    /// a largura da tela inteira para si — o controle nunca precisa disputar espaço.
    @ViewBuilder
    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(AppTypography.subheadlineMedium)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }
}

#Preview {
    OnboardingSetupStepView(viewModel: OnboardingViewModel(), onContinue: {})
        .background(AmbientBackground())
}
