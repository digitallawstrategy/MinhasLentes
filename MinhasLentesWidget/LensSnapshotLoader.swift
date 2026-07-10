import Foundation
import SwiftData

/// Retrato somente-leitura do par ativo mais antigo, usado para desenhar o widget sem expor
/// os modelos SwiftData diretamente às views (que rodam num processo separado do app).
struct LensSnapshot {
    var pairName: String?
    var usesRemaining: Int
    var usesCount: Int
    var maximumUses: Int
    var daysSinceCleaning: Int?
    var daysUntilNextCleaning: Int?
    var hasActivePair: Bool

    static let placeholder = LensSnapshot(
        pairName: "Par nº 1", usesRemaining: 59, usesCount: 1, maximumUses: 60,
        daysSinceCleaning: 3, daysUntilNextCleaning: 12, hasActivePair: true
    )

    static let empty = LensSnapshot(
        pairName: nil, usesRemaining: 0, usesCount: 0, maximumUses: 0,
        daysSinceCleaning: nil, daysUntilNextCleaning: nil, hasActivePair: false
    )
}

/// Lê o banco compartilhado do App Group para montar o retrato mostrado no widget. Usa um
/// schema reduzido (sem `HistoryEvent`, que só o app grava) — SwiftData não exige que todas as
/// tabelas do arquivo estejam declaradas no schema de quem está lendo.
enum LensSnapshotLoader {
    static func load() -> LensSnapshot {
        do {
            let schema = Schema([LensPair.self, LensUsage.self, CaseCleaning.self, AppSettings.self])
            let url = try AppGroup.storeURL()
            let configuration = ModelConfiguration(schema: schema, url: url)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let activeDescriptor = FetchDescriptor<LensPair>(
                predicate: #Predicate { $0.statusRawValue == "active" },
                sortBy: [SortDescriptor(\.sequenceNumber)]
            )
            guard let pair = try context.fetch(activeDescriptor).first else {
                return .empty
            }

            let intervalDays = try context.fetch(FetchDescriptor<AppSettings>()).first?.cleaningIntervalDays ?? 15
            let cleaningDescriptor = FetchDescriptor<CaseCleaning>(sortBy: [SortDescriptor(\.cleaningDate, order: .reverse)])
            let lastCleaning = try context.fetch(cleaningDescriptor).first

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
                pairName: pair.name,
                usesRemaining: pair.usesRemaining,
                usesCount: pair.usesCount,
                maximumUses: pair.maximumUses,
                daysSinceCleaning: daysSinceCleaning,
                daysUntilNextCleaning: daysUntilNextCleaning,
                hasActivePair: true
            )
        } catch {
            return .empty
        }
    }
}
