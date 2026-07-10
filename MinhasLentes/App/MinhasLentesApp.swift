import SwiftUI
import SwiftData

@main
struct MinhasLentesApp: App {
    let modelContainer: ModelContainer?
    let initializationErrorMessage: String?

    init() {
        let schema = Schema([
            LensPair.self,
            LensUsage.self,
            CaseCleaning.self,
            AppSettings.self,
            HistoryEvent.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            initializationErrorMessage = nil
        } catch {
            // Falha ao abrir o armazenamento local (ex.: disco cheio, arquivo corrompido).
            // Em vez de encerrar o processo com fatalError, mostramos uma tela explicando o
            // problema — o usuário pode então tentar liberar espaço, reiniciar o aparelho ou
            // reinstalar preservando um backup, conforme orientado nas instruções do projeto.
            modelContainer = nil
            initializationErrorMessage = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .modelContainer(modelContainer)
            } else {
                StartupFailureView(message: initializationErrorMessage ?? "Erro desconhecido ao abrir o armazenamento local.")
            }
        }
    }
}

/// Tela exibida somente se o `ModelContainer` não puder ser inicializado — cenário raro
/// (ex.: armazenamento corrompido ou sem espaço em disco). Nunca derruba o aplicativo.
private struct StartupFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Não foi possível abrir o armazenamento local",
            systemImage: "externaldrive.trianglebadge.exclamationmark",
            description: Text(message)
        )
    }
}
