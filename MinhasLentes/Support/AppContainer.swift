import Foundation
import SwiftData
import CloudKit

/// Único ponto de criação do `ModelContainer` principal do app, compartilhado entre
/// `MinhasLentesApp` (que o usa via `.modelContext` normalmente, através da árvore de Views) e
/// `NotificationManager` (que precisa agir sobre os dados a partir do handler de uma ação de
/// notificação, que pode rodar com o processo do app apenas acordado em segundo plano — sem que
/// nenhuma `View` chegue a aparecer).
///
/// Existir como um único `static let` garante que só um `ModelContainer` seja aberto por
/// processo, não importa qual caminho toque nele primeiro — abrir dois contêineres
/// independentes apontando para o mesmo arquivo do App Group é exatamente o tipo de colisão que
/// já causou "o arquivo não pôde ser aberto" antes neste projeto.
///
/// Dois stores possíveis, nunca o mesmo arquivo: o legado (`AppGroup.storeURL()`, sem CloudKit,
/// existe desde sempre) e o sincronizado (`AppGroup.cloudStoreURL()`, com CloudKit, novo). Qual
/// dos dois `shared()` abre é decidido de uma vez, na primeira chamada do processo, pela flag
/// `AppGroup.isCloudMigrationComplete` — nunca muda no meio de uma sessão já em andamento (ver
/// `attemptCloudMigrationIfNeeded()`).
@MainActor
enum AppContainer {
    private static var cached: Result<ModelContainer, Error>?

    static func shared() throws -> ModelContainer {
        if let cached {
            return try cached.get()
        }
        do {
            let container = try resolveContainer()
            cached = .success(container)
            return container
        } catch {
            cached = .failure(error)
            throw error
        }
    }

    private static func resolveContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)

        #if DEBUG
        if UITestSupport.isUITestRun() {
            // Store isolado e em memória, só para validação visual automatizada — nunca abre o
            // arquivo real do App Group. Sendo em memória, cada novo lançamento do processo
            // começa de uma base garantidamente vazia: não há "esvaziar" a fazer, e rodar isto
            // várias vezes seguidas não pode acumular nada, por construção (ao contrário de
            // reaproveitar o store real e checar "já tem dado?", que dependia dele estar vazio
            // da primeira vez e não se recuperava sozinho de uma segunda execução, nem nunca
            // chegaria perto de dado real de uso normal do app).
            //
            // Escopo desta escolha, de propósito: isto valida o LAYOUT da Home, não o
            // armazenamento real. Por não passar pelo App Group, esta execução nunca exercita
            // `AppGroup.storeURL()`/`migrateLegacyStoreIfNeeded`, a leitura do widget/Live
            // Activity a partir do mesmo arquivo, nem `AppMigrationPlan` contra um banco
            // pré-existente de uma versão anterior — para essas verificações, é preciso rodar
            // sem nenhum dos dois argumentos, contra o armazenamento real.
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
        #endif

        if AppGroup.isCloudMigrationComplete, let cloudContainer = try? openCloudContainer(schema: schema) {
            return cloudContainer
        }
        // Sem migração concluída ainda, ou o store com CloudKit falhou ao abrir por qualquer
        // motivo (arquivo corrompido, etc.) — cai pro store legado, que nunca foi tocado.
        // `attemptCloudMigrationIfNeeded()` tenta migrar e ativar o store com CloudKit na
        // próxima vez que o app abrir; esta sessão continua no legado normalmente.
        return try openLegacyContainer(schema: schema)
    }

    private static func openLegacyContainer(schema: Schema) throws -> ModelContainer {
        // O banco vive no App Group, não no contêiner privado do app, para que o widget e
        // a Live Activity (processos separados) consigam ler os mesmos dados.
        let url = try AppGroup.storeURL()
        AppGroup.migrateLegacyStoreIfNeeded(to: url)
        // `cloudKitDatabase: .none` explícito — o padrão de `ModelConfiguration` é `.automatic`,
        // que (agora que o app tem o entitlement de CloudKit) tentaria sincronizar este store
        // sozinho. Este é o store legado, local-only, que nunca deve sincronizar por si — o
        // store com CloudKit é um arquivo separado, deliberadamente, para nunca arriscar os
        // dados já existentes de quem já tem o app instalado (ver `CloudSyncMigrationService`).
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])
    }

    /// Sem `migrationPlan:` de propósito — existe um bug documentado do SwiftData ao combinar
    /// `migrationPlan:` com `cloudKitDatabase:` na mesma configuração. Este store nunca precisou
    /// de migração de schema (nasce direto em `AppSchemaV1`); quem migra o CONTEÚDO do store
    /// legado pra cá é `CloudSyncMigrationService`, uma vez, não o SwiftData reinterpretando um
    /// arquivo antigo no lugar.
    private static func openCloudContainer(schema: Schema) throws -> ModelContainer {
        let url = try AppGroup.cloudStoreURL()
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Tenta migrar o store legado para o store com CloudKit — só tem efeito visível na PRÓXIMA
    /// vez que o app abrir, nunca na sessão atual: `shared()` já resolveu e cacheou o container
    /// desta sessão antes desta função sequer poder rodar (chamada depois que a UI já está de
    /// pé, ver `MinhasLentesApp`), e trocar o container "debaixo" de uma UI já montada e
    /// vinculada a ele arriscaria os dois lados divergirem (widget/notificação gravando no store
    /// novo enquanto a UI aberta continua no antigo). Por isso não invalida `cached` — só prepara
    /// o terreno para a próxima resolução de `shared()`.
    ///
    /// Não faz nada (silenciosamente) se: já migrou antes, não há conta iCloud disponível, ou é
    /// uma execução de UI test/DEBUG em memória. Qualquer falha na migração em si (ex.: erro de
    /// disco) é ignorada — o app continua no store local até a próxima tentativa, nunca trava
    /// nem perde dado.
    static func attemptCloudMigrationIfNeeded() async {
        #if DEBUG
        if UITestSupport.isUITestRun() { return }
        #endif
        guard !AppGroup.isCloudMigrationComplete else { return }

        let accountStatus = try? await CKContainer.default().accountStatus()
        guard accountStatus == .available else { return }

        do {
            let legacyContext = ModelContext(try shared())
            let schema = Schema(versionedSchema: AppSchemaV1.self)
            let cloudContext = ModelContext(try openCloudContainer(schema: schema))
            try CloudSyncMigrationService.migrate(from: legacyContext, to: cloudContext)
            AppGroup.isCloudMigrationComplete = true
        } catch {
            // Melhor esforço — ver comentário acima. Tenta de novo na próxima chamada.
        }
    }
}
