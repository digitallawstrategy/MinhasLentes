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
            let schema = Schema([
                LensPair.self,
                LensUsage.self,
                CaseCleaning.self,
                AppSettings.self,
                HistoryEvent.self,
                LensCase.self,
                RoutineCareLog.self,
                CleaningSolution.self,
                LensInventoryItem.self,
                EyeCareProfessional.self,
                EyeAppointment.self,
                WearSession.self,
            ])
            // O banco vive no App Group, não no contêiner privado do app, para que o widget e
            // a Live Activity (processos separados) consigam ler os mesmos dados.
            let url = try AppGroup.storeURL()
            AppGroup.migrateLegacyStoreIfNeeded(to: url)
            let configuration = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            cached = .success(container)
            return container
        } catch {
            cached = .failure(error)
            throw error
        }
    }
}
