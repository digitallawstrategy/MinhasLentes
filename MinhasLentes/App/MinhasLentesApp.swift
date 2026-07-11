import SwiftUI
import SwiftData

@main
struct MinhasLentesApp: App {
    let modelContainer: ModelContainer?
    let initializationErrorMessage: String?

    init() {
        // Registra o delegate de notificações (e a categoria/ação "Retirei agora") o quanto
        // antes no ciclo de vida do processo — inclusive quando o app é apenas acordado em
        // segundo plano por causa de uma notificação, cenário em que a árvore de Views pode
        // nunca chegar a existir. `NotificationManager.shared` é lazy; sem tocar nele aqui,
        // nada garante que o delegate esteja pronto a tempo de o sistema entregar a resposta.
        _ = NotificationManager.shared
        do {
            let container = try AppContainer.shared()
            modelContainer = container
            initializationErrorMessage = nil
            // Migração: `hasCompletedOnboarding` não existia antes desta versão. Para uma
            // instalação já em uso — reconhecida aqui por já ter pelo menos um par —, o valor
            // padrão `false` faria o app voltar a mostrar a tela de boas-vindas, escondendo
            // (nunca apagando) os dados reais atrás dela. Corrige isso antes de qualquer View
            // aparecer, para nunca mostrar o onboarding por engano a quem já usa o app.
            Self.migrateOnboardingFlagIfNeeded(container: container)
        } catch {
            // Falha ao abrir o armazenamento local (ex.: disco cheio, arquivo corrompido).
            // Em vez de encerrar o processo com fatalError, mostramos uma tela explicando o
            // problema — o usuário pode então tentar liberar espaço, reiniciar o aparelho ou
            // reinstalar preservando um backup, conforme orientado nas instruções do projeto.
            modelContainer = nil
            initializationErrorMessage = error.localizedDescription
        }
    }

    private static func migrateOnboardingFlagIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        guard let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first, !settings.hasCompletedOnboarding else { return }
        let hasAnyPair = ((try? context.fetchCount(FetchDescriptor<LensPair>())) ?? 0) > 0
        guard hasAnyPair else { return }
        settings.hasCompletedOnboarding = true
        try? context.save()
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
