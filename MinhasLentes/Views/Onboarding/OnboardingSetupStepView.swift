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
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Vamos configurar seu par")
                        .font(AppTypography.title)
                    Text("Você pode ajustar tudo isso depois, a qualquer momento.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                }

                AppCard {
                    Text("Novo par de lentes")
                        .font(AppTypography.headline)
                    DatePicker("Data de início", selection: $viewModel.startDate, displayedComponents: .date)
                    Stepper("Limite de usos: \(viewModel.maximumUses)", value: $viewModel.maximumUses, in: 1...500)
                    Picker("Modo de controle", selection: $viewModel.trackingMode) {
                        ForEach(TrackingMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                AppCard {
                    Text("Estojo")
                        .font(AppTypography.headline)
                    DatePicker("Última limpeza registrada", selection: $viewModel.lastCleaningDate, displayedComponents: .date)
                }

                PrimaryActionButton(title: "Continuar", isDisabled: viewModel.isCompleting, action: onContinue)
                    .overlay {
                        if viewModel.isCompleting {
                            ProgressView().tint(.white)
                        }
                    }
            }
            .padding(AppSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

#Preview {
    OnboardingSetupStepView(viewModel: OnboardingViewModel(), onContinue: {})
        .background(AmbientBackground())
}
