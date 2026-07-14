import SwiftUI
import SwiftData

/// Passo do fluxo de primeira abertura — estado de UI do próprio onboarding, não roteamento de
/// app inteiro (diferente de `AppTab`, em `Support/AppRouter.swift`), por isso mora aqui.
enum OnboardingStep: String, CaseIterable {
    case welcome
    case benefits
    case setup
    case notifications
}

/// Fluxo exibido na primeira abertura, quando ainda não existe nenhum par ativo: 4 passos
/// (boas-vindas → benefícios → configuração inicial → notificações). Cada passo é uma View
/// própria (`OnboardingWelcomeStepView`, `OnboardingBenefitsStepView`, `OnboardingSetupStepView`,
/// `NotificationPermissionView`); este arquivo só coordena — qual passo mostrar, a transição
/// entre eles, e o momento exato em que o onboarding é marcado como concluído (sempre ao final do
/// passo de notificações, não antes — ver `OnboardingViewModel.completeOnboarding`).
///
/// Sem `NavigationStack`/barra de navegação nativa de propósito: nenhum dos 4 passos precisa de
/// título nativo ou push, e uma tela cheia sem esse chrome é o que dá a sensação de apresentação
/// (não de formulário) pedida para esta tela.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allSettings: [AppSettings]

    @State private var step: OnboardingStep = .welcome
    @State private var navigationEdge: Edge = .trailing
    @State private var viewModel = OnboardingViewModel()
    @State private var settingsLoadError: IdentifiableError?

    private var settings: AppSettings? {
        allSettings.first
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                header
                currentStepView
                    .transition(stepTransition)
                    .frame(maxHeight: .infinity)
            }
        }
        .task {
            do {
                _ = try AppSettingsStore.currentSettings(context: modelContext)
            } catch {
                settingsLoadError = IdentifiableError(error)
            }
            #if DEBUG
            if let requestedStep = UITestSupport.requestedOnboardingStep() {
                step = requestedStep
            }
            #endif
        }
        .alert(
            "Não foi possível preparar o armazenamento",
            isPresented: Binding(
                get: { settingsLoadError != nil },
                set: { if !$0 { settingsLoadError = nil } }
            ),
            presenting: settingsLoadError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
        .alert(
            "Não foi possível concluir a ação",
            isPresented: Binding(
                get: { viewModel.presentedError != nil },
                set: { if !$0 { viewModel.presentedError = nil } }
            ),
            presenting: viewModel.presentedError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeStepView(onBegin: { advance(to: .benefits) })
        case .benefits:
            OnboardingBenefitsStepView(onContinue: { advance(to: .setup) })
        case .setup:
            OnboardingSetupStepView(viewModel: viewModel, onContinue: { Task { await completeSetup() } })
        case .notifications:
            NotificationPermissionView(
                onContinue: { Task { await finishOnboarding(requestingNotifications: true) } },
                onSkip: { Task { await finishOnboarding(requestingNotifications: false) } }
            )
        }
    }

    private var header: some View {
        HStack {
            Group {
                if step != .welcome {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Voltar")
                } else {
                    Color.clear
                }
            }
            .frame(width: 40, height: 40)
            .background(step != .welcome ? AppColor.surfaceElevated : Color.clear, in: Circle())
            .pressScale()

            Spacer()
            stepDots
            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    private var stepDots: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(OnboardingStep.allCases, id: \.self) { candidate in
                Capsule()
                    .fill(candidate == step ? AppColor.primary : Color.secondary.opacity(0.25))
                    .frame(width: candidate == step ? 20 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Etapa \(stepIndex + 1) de \(OnboardingStep.allCases.count)")
    }

    private var stepIndex: Int {
        OnboardingStep.allCases.firstIndex(of: step) ?? 0
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let oppositeEdge: Edge = navigationEdge == .trailing ? .leading : .trailing
        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: navigationEdge)),
            removal: .opacity.combined(with: .move(edge: oppositeEdge))
        )
    }

    private func advance(to next: OnboardingStep) {
        navigationEdge = .trailing
        withAnimation(reduceMotion ? .default : AppAnimation.standard) {
            step = next
        }
    }

    private func back() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: step), currentIndex > 0 else { return }
        navigationEdge = .leading
        withAnimation(reduceMotion ? .default : AppAnimation.standard) {
            step = OnboardingStep.allCases[currentIndex - 1]
        }
    }

    private func completeSetup() async {
        guard let settings else { return }
        let success = await viewModel.createInitialData(settings: settings, context: modelContext)
        guard success else { return }
        advance(to: .notifications)
    }

    /// Chamado pelas duas ações do passo de notificações — permitir ou pular. Em ambos os casos
    /// o onboarding é concluído ao final: notificação negada/pulada não deve prender o usuário.
    private func finishOnboarding(requestingNotifications: Bool) async {
        guard let settings else { return }
        if requestingNotifications {
            await viewModel.requestNotificationsAndSchedule(settings: settings)
        }
        viewModel.completeOnboarding(settings: settings, context: modelContext)
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [LensPair.self, LensUsage.self, CaseCleaning.self, AppSettings.self, HistoryEvent.self], inMemory: true)
}
