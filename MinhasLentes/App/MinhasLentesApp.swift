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
            #if DEBUG
            Self.seedForUITestingIfRequested(container: container)
            #endif
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

    #if DEBUG
    /// Só existe em build DEBUG (não compila em release) e só age com o argumento de
    /// lançamento `-uiTestSeedData` presente — sem isso, é inerte. Roda contra o `ModelContainer`
    /// isolado em memória que `AppContainer.shared()` já retorna para esse mesmo argumento (ver
    /// lá): nunca é o armazenamento real do App Group, e sendo em memória, todo novo lançamento
    /// do processo começa de uma base garantidamente vazia. Por isso não existe mais um "já tem
    /// dado? então não faz nada" aqui — a determinismo/idempotência vêm da própria natureza do
    /// container, não de uma checagem que dependia dele já estar vazio da primeira vez.
    ///
    /// Insere direto nos modelos, não pelos Services/ViewModels de propósito: os Services também
    /// disparam agendamento de notificação e apresentação de Live Activity, que dependem de
    /// autorização do sistema (variável entre simuladores/execuções) e não seriam
    /// determinísticos — o que este seed precisa garantir é só o estado visual da Home.
    private static func seedForUITestingIfRequested(container: ModelContainer) {
        guard AppContainer.isUITestSeedRequested else { return }
        let context = container.mainContext

        let settings = AppSettings()
        settings.hasCompletedOnboarding = true
        context.insert(settings)

        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()

        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: startDate,
            maximumUses: 60,
            trackingMode: .pair,
            side: .both
        )
        context.insert(pair)
        context.insert(LensUsage(date: startDate, side: .both, lensPair: pair))

        context.insert(CaseCleaning(cleaningDate: startDate))
        context.insert(LensCase(startDate: startDate, intervalDays: 90))
        context.insert(CleaningSolution(
            brand: "Marca de exemplo",
            product: "Solução multiuso",
            openedDate: startDate,
            postOpeningShelfLifeDays: 90
        ))

        try? context.save()
    }
    #endif

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
