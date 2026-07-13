import SwiftUI
import SwiftData

/// Raiz de navegação: decide entre o fluxo de boas-vindas e a TabView principal, dependendo
/// da existência de um par ativo.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allSettings: [AppSettings]

    @State private var startupError: IdentifiableError?
    @State private var router = AppRouter.shared

    /// Uma vez concluído, o onboarding nunca mais volta — mesmo que todos os pares sejam
    /// encerrados ou excluídos depois. Estojo, solução, estoque, consultas e histórico não
    /// dependem de haver um par ativo; gatear a navegação principal pela existência de um par
    /// prenderia o usuário no onboarding sem acesso a esses módulos.
    private var hasCompletedOnboarding: Bool {
        allSettings.first?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        Group {
            if let startupError {
                startupErrorView(startupError)
            } else if hasCompletedOnboarding {
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
            // Reagenda tudo que pode ter ficado pendente (estojo, solução, estoque, consultas,
            // sessão de uso) e restaura a Live Activity/corrige uma sessão órfã, se for o caso.
            await NotificationReconciliationService.rebuildAll(context: modelContext, settings: settings)
        } catch {
            startupError = IdentifiableError(error)
        }
    }

    /// Avaliado e descartado: uma `FloatingTabBar` totalmente customizada (substituindo a
    /// `TabView` nativa) perderia comportamentos automáticos do sistema — rolar ao topo com
    /// duplo toque, convenções de VoiceOver/rotor para navegação por abas — só para conseguir um
    /// brilho decorativo atrás do ícone selecionado. No iOS desta base, a `TabView` nativa já
    /// renderiza como uma barra flutuante arredondada por conta própria (visível nos prints do
    /// aparelho real); o `.tint` abaixo só deixa explícito, em código, que a cor de seleção é a
    /// mesma cor de marca do resto do app, em vez de depender implicitamente do accent color
    /// global do projeto.
    private var mainTabs: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Início", systemImage: "house") }
                .tag(AppTab.home)
            LensPairsView()
                .tabItem { Label("Lentes", systemImage: "eye") }
                .tag(AppTab.lentes)
            CuidadosView()
                .tabItem { Label("Cuidados", systemImage: "heart.text.square") }
                .tag(AppTab.cuidados)
            EyeCareView()
                .tabItem { Label("Consultas", systemImage: "calendar.badge.clock") }
                .tag(AppTab.consultas)
            SettingsView()
                .tabItem { Label("Mais", systemImage: "ellipsis.circle") }
                .tag(AppTab.settings)
        }
        .tint(AppColor.primary)
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
