import Foundation
import SwiftData

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
@MainActor
enum AppContainer {
    private static var cached: Result<ModelContainer, Error>?

    static func shared() throws -> ModelContainer {
        if let cached {
            return try cached.get()
        }
        do {
            let schema = Schema(versionedSchema: AppSchemaV1.self)
            let configuration: ModelConfiguration
            #if DEBUG
            if UITestSupport.isUITestRun() {
                // Store isolado e em memória, só para validação visual automatizada — nunca
                // abre o arquivo real do App Group. Sendo em memória, cada novo lançamento do
                // processo começa de uma base garantidamente vazia: não há "esvaziar" a fazer, e
                // rodar isto várias vezes seguidas não pode acumular nada, por construção (ao
                // contrário de reaproveitar o store real e checar "já tem dado?", que dependia
                // dele estar vazio da primeira vez e não se recuperava sozinho de uma segunda
                // execução, nem nunca chegaria perto de dado real de uso normal do app).
                //
                // Escopo desta escolha, de propósito: isto valida o LAYOUT da Home, não o
                // armazenamento real. Por não passar pelo App Group, esta execução nunca exercita
                // `AppGroup.storeURL()`/`migrateLegacyStoreIfNeeded`, a leitura do widget/Live
                // Activity a partir do mesmo arquivo, nem `AppMigrationPlan` contra um banco
                // pré-existente de uma versão anterior — para essas verificações, é preciso rodar
                // sem nenhum dos dois argumentos, contra o armazenamento real.
                configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            } else {
                configuration = try Self.realConfiguration(schema: schema)
            }
            #else
            configuration = try Self.realConfiguration(schema: schema)
            #endif
            let container = try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])
            cached = .success(container)
            return container
        } catch {
            cached = .failure(error)
            throw error
        }
    }

    private static func realConfiguration(schema: Schema) throws -> ModelConfiguration {
        // O banco vive no App Group, não no contêiner privado do app, para que o widget e
        // a Live Activity (processos separados) consigam ler os mesmos dados.
        let url = try AppGroup.storeURL()
        AppGroup.migrateLegacyStoreIfNeeded(to: url)
        return ModelConfiguration(schema: schema, url: url)
    }
}
