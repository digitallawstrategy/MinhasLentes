import SwiftUI
import SwiftData

/// Raiz de navegação: decide entre o fluxo de boas-vindas e a TabView principal, dependendo
/// da existência de um par ativo.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var pairs: [LensPair]

    @State private var startupError: IdentifiableError?
    @State private var router = AppRouter.shared

    private var hasAnyPair: Bool {
        pairs.contains { $0.status != .finished && $0.deletedAt == nil }
    }

    var body: some View {
        Group {
            if let startupError {
                startupErrorView(startupError)
            } else if hasAnyPair {
                mainTabs
            } else {
                OnboardingView()
            }
        }
        .task {
            await runIdempotentStartupChecks()
        }
        // Cobre o app voltando de segundo plano sem ter sido relançado do zero — sem isso, o
        // lembrete repetitivo de tempo de uso excessivo só seria reagendado num cold launch,
        // parando de avisar silenciosamente se o app nunca for encerrado de fato.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await runIdempotentStartupChecks() }
        }
        .onOpenURL { url in
            router.handle(url: url)
        }
    }

    /// Tudo aqui é seguro de rodar repetidamente: tanto no lançamento quanto toda vez que o
    /// app volta a ficar ativo. Nenhuma chamada duplica dados ou notificações.
    private func runIdempotentStartupChecks() async {
        do {
            let settings = try AppSettingsStore.currentSettings(context: modelContext)
            // Idempotente: corrige qualquer inconsistência de "mais de um par em uso por
            // lado" residual de dados anteriores ao conceito de reserva.
            try LensPairService.normalizeInUseInvariant(context: modelContext)
            // Idempotente: apaga de vez pares na lixeira há mais de trashRetentionDays dias.
            try LensPairService.purgeExpiredTrash(context: modelContext)
            // Idempotente: se o ciclo ativo do estojo já passou do prazo recomendado e não
            // há lembrete periódico pendente, agenda um — ver NotificationManager para o
            // motivo de isso não poder ser agendado com antecedência.
            if let activeCase = try LensCaseService.activeCase(context: modelContext) {
                await NotificationManager.shared.refreshOverdueCaseReminder(
                    dueDate: activeCase.nextRecommendedReplacementDate,
                    settings: settings
                )
            }
            if let activeSolution = try CleaningSolutionService.activeSolution(context: modelContext) {
                await NotificationManager.shared.refreshOverdueSolutionReminder(
                    discardDate: activeSolution.discardDate,
                    settings: settings
                )
            }
            // Nunca perder a sessão: se houver um WearSession ativo mas nenhuma Live
            // Activity correspondente (o sistema pode ter encerrado a Live Activity, o
            // widget reiniciado, o app sido fechado, ou o iPhone reiniciado), restaura a
            // apresentação a partir dos dados persistidos — nunca o contrário.
            if let activeSession = try WearSessionService.activeSession(context: modelContext), let pair = activeSession.lensPair {
                if !LiveActivityService.hasActiveWearingSession() {
                    await LiveActivityService.presentWearingSession(
                        pairID: pair.id, pairName: pair.name, usesRemaining: pair.usesRemaining, maximumUses: pair.maximumUses,
                        wearingSince: activeSession.startedAt, settings: settings
                    )
                }
                // Idempotente: `add(request:)` substitui uma notificação pendente com o
                // mesmo identificador em vez de duplicar — seguro reagendar toda vez.
                try? await NotificationManager.shared.scheduleWearingExcessiveNotifications(wearingSince: activeSession.startedAt, settings: settings)
                await NotificationManager.shared.refreshWearingExcessiveRepeatReminder(wearingSince: activeSession.startedAt, settings: settings)
            }
        } catch {
            startupError = IdentifiableError(error)
        }
    }

    private var mainTabs: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Início", systemImage: "house") }
                .tag(AppTab.home)
            LensPairsView()
                .tabItem { Label("Lentes", systemImage: "eye") }
                .tag(AppTab.lentes)
            CaseView()
                .tabItem { Label("Estojo", systemImage: "shippingbox") }
                .tag(AppTab.estojo)
            CleaningSolutionView()
                .tabItem { Label("Solução", systemImage: "flask") }
                .tag(AppTab.solution)
            EyeCareView()
                .tabItem { Label("Consultas", systemImage: "stethoscope") }
                .tag(AppTab.consultas)
            SettingsView()
                .tabItem { Label("Configurações", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }

    private func startupErrorView(_ error: IdentifiableError) -> some View {
        ContentUnavailableView(
            "Não foi possível abrir o armazenamento local",
            systemImage: "exclamationmark.triangle",
            description: Text(error.message)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
