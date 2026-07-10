import SwiftUI
import SwiftData

/// Raiz de navegação: decide entre o fluxo de boas-vindas e a TabView principal, dependendo
/// da existência de um par ativo.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
            } catch {
                startupError = IdentifiableError(error)
            }
        }
        .onOpenURL { url in
            router.handle(url: url)
        }
    }

    private var mainTabs: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Início", systemImage: "eye") }
                .tag(AppTab.home)
            HistoryView()
                .tabItem { Label("Histórico", systemImage: "clock") }
                .tag(AppTab.history)
            CaseView()
                .tabItem { Label("Estojo", systemImage: "shippingbox") }
                .tag(AppTab.estojo)
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
