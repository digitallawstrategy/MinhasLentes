import Foundation
import SwiftData

/// Retrato somente-leitura do par em uso mais antigo, usado para desenhar o widget sem expor
/// os modelos SwiftData diretamente às views (que rodam num processo separado do app).
struct LensSnapshot {
    var pairID: UUID?
    var pairName: String?
    var usesRemaining: Int
    var usesCount: Int
    var maximumUses: Int
    var daysSinceCleaning: Int?
    var daysUntilNextCleaning: Int?
    var hasActivePair: Bool
    /// Só preenchido em builds DEBUG quando `hasActivePair` é falso — mostrado na própria tela
    /// do widget para dar visibilidade a um problema que, de outra forma, ficaria completamente
    /// silencioso (não há como anexar o depurador a um widget rodando na tela de início).
    var debugMessage: String?

    static let placeholder = LensSnapshot(
        pairID: UUID(), pairName: "Par nº 1", usesRemaining: 59, usesCount: 1, maximumUses: 60,
        daysSinceCleaning: 3, daysUntilNextCleaning: 12, hasActivePair: true, debugMessage: nil
    )

    static let empty = LensSnapshot(
        pairID: nil, pairName: nil, usesRemaining: 0, usesCount: 0, maximumUses: 0,
        daysSinceCleaning: nil, daysUntilNextCleaning: nil, hasActivePair: false, debugMessage: nil
    )
}

/// Lê o banco compartilhado do App Group para montar o retrato mostrado no widget. Usa um
/// schema reduzido (sem `HistoryEvent`, que só o app grava) — SwiftData não exige que todas as
/// tabelas do arquivo estejam declaradas no schema de quem está lendo.
enum LensSnapshotLoader {
    /// Reaberto uma vez por processo da extensão, não a cada atualização do widget — abrir o
    /// arquivo do App Group repetidas vezes, de um processo separado do app, é justamente o
    /// tipo de coisa que pode colidir com uma gravação do app acontecendo no mesmo instante.
    private static var cachedContainer: ModelContainer?

    private static func sharedContainer() throws -> ModelContainer {
        if let cachedContainer { return cachedContainer }
        let schema = Schema([LensPair.self, LensUsage.self, CaseCleaning.self, AppSettings.self])
        let url = try AppGroup.storeURL()
        let configuration = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        cachedContainer = container
        return container
    }

    static func load() -> LensSnapshot {
        do {
            let context = ModelContext(try sharedContainer())

            let inUseDescriptor = FetchDescriptor<LensPair>(
                predicate: #Predicate { $0.statusRawValue == "inUse" && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.sequenceNumber)]
            )
            guard let pair = try context.fetch(inUseDescriptor).first else {
                #if DEBUG
                let allPairs = (try? context.fetch(FetchDescriptor<LensPair>())) ?? []
                let statuses = allPairs.map { "\($0.statusRawValue)\($0.deletedAt != nil ? "(lixeira)" : "")" }
                var snapshot = LensSnapshot.empty
                snapshot.debugMessage = "Sem par 'inUse'. \(allPairs.count) par(es) no banco: \(statuses)"
                return snapshot
                #else
                return .empty
                #endif
            }

            let intervalDays = try context.fetch(FetchDescriptor<AppSettings>()).first?.cleaningIntervalDays ?? 15
            let cleaningDescriptor = FetchDescriptor<CaseCleaning>(sortBy: [SortDescriptor(\.cleaningDate, order: .reverse)])
            let lastCleaning = try context.fetch(cleaningDescriptor).first

            // Cálculo de dias replicado aqui (em vez de usar LensStatisticsService) de propósito:
            // este arquivo só depende dos modelos SwiftData compartilhados via App Group, para
            // não precisar estender a membership do target do widget a mais um arquivo do app.
            var daysSinceCleaning: Int?
            var daysUntilNextCleaning: Int?
            if let lastCleaning {
                let calendar = Calendar.current
                let startOfLastCleaning = calendar.startOfDay(for: lastCleaning.cleaningDate)
                let startOfToday = calendar.startOfDay(for: Date())
                daysSinceCleaning = calendar.dateComponents([.day], from: startOfLastCleaning, to: startOfToday).day
                let nextDate = calendar.date(byAdding: .day, value: intervalDays, to: startOfLastCleaning) ?? Date()
                daysUntilNextCleaning = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: nextDate)).day
            }

            return LensSnapshot(
                pairID: pair.id,
                pairName: pair.name,
                usesRemaining: pair.usesRemaining,
                usesCount: pair.usesCount,
                maximumUses: pair.maximumUses,
                daysSinceCleaning: daysSinceCleaning,
                daysUntilNextCleaning: daysUntilNextCleaning,
                hasActivePair: true
            )
        } catch {
            #if DEBUG
            var snapshot = LensSnapshot.empty
            snapshot.debugMessage = "Erro ao ler o App Group: \(error)"
            return snapshot
            #else
            return .empty
            #endif
        }
    }
}
