import SwiftUI
import SwiftData

/// Raiz de navegação: decide entre o fluxo de boas-vindas e a TabView principal, dependendo
/// da existência de um par ativo.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var pairs: [LensPair]

    @State private var startupError: IdentifiableError?

    private var hasActivePair: Bool {
        pairs.contains { $0.status == .active }
    }

    var body: some View {
        Group {
            if let startupError {
                startupErrorView(startupError)
            } else if hasActivePair {
                mainTabs
            } else {
                OnboardingView()
            }
        }
        .task {
            do {
                _ = try AppSettingsStore.currentSettings(context: modelContext)
            } catch {
                startupError = IdentifiableError(error)
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            HomeView()
                .tabItem { Label("Início", systemImage: "eye") }
            HistoryView()
                .tabItem { Label("Histórico", systemImage: "clock") }
            CaseView()
                .tabItem { Label("Estojo", systemImage: "shippingbox") }
            SettingsView()
                .tabItem { Label("Configurações", systemImage: "gearshape") }
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
