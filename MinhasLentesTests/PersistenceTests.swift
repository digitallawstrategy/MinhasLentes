import XCTest
import SwiftData
@testable import MinhasLentes

/// Confirma que os dados sobrevivem ao equivalente de fechar e reabrir o aplicativo:
/// um novo `ModelContainer` apontando para o mesmo arquivo em disco enxerga os mesmos dados.
@MainActor
final class PersistenceTests: XCTestCase {

    func testDataPersistsAcrossContainerRecreation() throws {
        let schema = Schema([LensPair.self, LensUsage.self, CaseCleaning.self, AppSettings.self, HistoryEvent.self])
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MinhasLentesPersistenceTest-\(UUID().uuidString).sqlite")

        do {
            let configuration = ModelConfiguration(schema: schema, url: tempURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let pair = try LensPairService.startNewPair(
                name: nil, startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
                trackingMode: .pair, side: .both, context: context
            )
            _ = try LensPairService.registerUsage(
                for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
                allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
            )
            let cleaning = CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 10))
            context.insert(cleaning)
            try context.save()
        }

        // Simula reabrir o aplicativo: novo ModelContainer apontando para o mesmo arquivo.
        let configuration2 = ModelConfiguration(schema: schema, url: tempURL)
        let container2 = try ModelContainer(for: schema, configurations: [configuration2])
        let context2 = ModelContext(container2)

        let pairs = try LensPairService.allPairs(context: context2)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.usesCount, 1)
        XCTAssertEqual(pairs.first?.name, "Par nº 1")

        let cleaningDescriptor = FetchDescriptor<CaseCleaning>()
        let cleanings = (try? context2.fetch(cleaningDescriptor)) ?? []
        XCTAssertEqual(cleanings.count, 1)

        try? FileManager.default.removeItem(at: tempURL)
    }
}
