import XCTest
import SwiftData
@testable import MinhasLentes

/// Confirma que os dados sobrevivem ao equivalente de fechar e reabrir o aplicativo: um novo
/// `ModelContainer` apontando para o mesmo arquivo em disco enxerga os mesmos dados — e,
/// especificamente, que abrir um arquivo criado ANTES de `AppSchemaV1`/`AppMigrationPlan`
/// existirem (schema sem versão, sem plano de migração) com a configuração atual não faz o
/// SwiftData tratar o arquivo como incompatível e começar de uma base vazia.
///
/// Usa o schema completo atual (`AppSchemaV1.models`), não um subconjunto — um teste que só
/// cobre `LensPair`/`LensUsage`/`CaseCleaning` não teria como pegar um problema específico de
/// `RoutineCareLog` ou de qualquer outro modelo adicionado depois.
@MainActor
final class PersistenceTests: XCTestCase {
    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MinhasLentesPersistenceTest-\(UUID().uuidString).sqlite")
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    // MARK: - Persistência básica com o schema completo atual

    func testDataPersistsAcrossContainerRecreation() throws {
        let tempURL = makeTempURL()
        defer { removeStore(at: tempURL) }

        do {
            let container = try makeCurrentContainer(url: tempURL)
            let context = ModelContext(container)

            let pair = try LensPairService.startNewPair(
                name: nil, startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
                trackingMode: .pair, side: .both, context: context
            )
            _ = try LensPairService.registerUsage(
                for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
                allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
            )
            context.insert(CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 10)))
            context.insert(RoutineCareLog(date: TestSupport.date(2026, 7, 10)))
            context.insert(LensCase(startDate: TestSupport.date(2026, 7, 10), intervalDays: 90))
            context.insert(CleaningSolution(
                brand: "Marca", product: "Solução", openedDate: TestSupport.date(2026, 7, 10), postOpeningShelfLifeDays: 90
            ))
            context.insert(LensInventoryItem(brand: "Marca", model: "Modelo", side: .both, initialQuantity: 1))
            let professional = EyeCareProfessional(name: "Dra. Exemplo")
            context.insert(professional)
            context.insert(EyeAppointment(
                date: TestSupport.date(2026, 8, 1), type: .routine, recommendedFollowUpMonths: 12, professional: professional
            ))
            context.insert(WearSession(startedAt: TestSupport.date(2026, 7, 10), lensPair: pair))
            try context.save()
        }

        // Simula reabrir o aplicativo: novo ModelContainer apontando para o mesmo arquivo.
        let container2 = try makeCurrentContainer(url: tempURL)
        let context2 = ModelContext(container2)

        XCTAssertEqual(try LensPairService.allPairs(context: context2).count, 1)
        XCTAssertEqual(try context2.fetchCount(FetchDescriptor<CaseCleaning>()), 1)
        XCTAssertEqual(try context2.fetchCount(FetchDescriptor<RoutineCareLog>()), 1)
        XCTAssertEqual(try context2.fetchCount(FetchDescriptor<LensCase>()), 1)
        XCTAssertEqual(try context2.fetchCount(FetchDescriptor<CleaningSolution>()), 1)
        XCTAssertEqual(try context2.fetchCount(FetchDescriptor<LensInventoryItem>()), 1)
        XCTAssertEqual(try context2.fetchCount(FetchDescriptor<EyeCareProfessional>()), 1)
        XCTAssertEqual(try context2.fetchCount(FetchDescriptor<EyeAppointment>()), 1)
        XCTAssertEqual(try context2.fetchCount(FetchDescriptor<WearSession>()), 1)
    }

    /// O sintoma relatado é especificamente sobre o calendário de cuidado diário — este teste
    /// isola só `RoutineCareLog`, com vários registros em datas diferentes, exatamente o
    /// cenário de semanas de uso real (não um único registro de teste).
    func testMultipleRoutineCareLogsPersistAcrossContainerRecreation() throws {
        let tempURL = makeTempURL()
        defer { removeStore(at: tempURL) }

        let dates = [
            TestSupport.date(2026, 6, 20),
            TestSupport.date(2026, 6, 21),
            TestSupport.date(2026, 6, 23),
            TestSupport.date(2026, 6, 25),
            TestSupport.date(2026, 6, 28),
            TestSupport.date(2026, 7, 1),
            TestSupport.date(2026, 7, 5),
        ]

        do {
            let container = try makeCurrentContainer(url: tempURL)
            let context = ModelContext(container)
            for date in dates {
                context.insert(RoutineCareLog(date: date))
            }
            try context.save()
        }

        let reopened = try makeCurrentContainer(url: tempURL)
        let reopenedContext = ModelContext(reopened)
        let logs = try reopenedContext.fetch(FetchDescriptor<RoutineCareLog>())
        XCTAssertEqual(logs.count, dates.count, "Nenhum registro de cuidado diário pode desaparecer ao reabrir o mesmo arquivo")

        let calendar = Calendar.current
        for expectedDate in dates {
            XCTAssertTrue(
                logs.contains { calendar.isDate($0.date, inSameDayAs: expectedDate) },
                "Registro de \(expectedDate) sumiu ao reabrir o armazenamento"
            )
        }
    }

    // MARK: - Compatibilidade com um arquivo anterior a AppSchemaV1/AppMigrationPlan

    /// Reproduz de propósito a configuração exata de `AppContainer` em `73bf77f` (o commit
    /// imediatamente anterior a `AppSchemaV1`/`AppMigrationPlan` serem introduzidos nesta
    /// branch): `Schema([...lista de modelos...])` sem versão nenhuma, `ModelContainer(for:
    /// configurations:)` sem `migrationPlan`. Isto é o formato de arquivo que qualquer instalação
    /// real do app tem hoje, de antes desta mudança.
    private func makeLegacyContainer(url: URL) throws -> ModelContainer {
        let schema = Schema(AppSchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Reproduz a configuração atual de `AppContainer.shared()` exatamente — mesma chamada,
    /// mesmo schema versionado, mesmo plano de migração.
    private func makeCurrentContainer(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [configuration])
    }

    /// O teste que mais importa desta rodada: alguém que já tinha o app instalado ANTES desta
    /// branch, com cuidados diários já registrados no arquivo real, atualiza para uma versão que
    /// passou a abrir o mesmo arquivo com `Schema(versionedSchema: AppSchemaV1.self)` +
    /// `AppMigrationPlan`. Se o SwiftData tratar isso como um schema incompatível (por não ter
    /// vindo de uma versão anterior registrada no plano), o sintoma seria exatamente o
    /// reportado: o app abre normalmente, mas os dados anteriores não aparecem mais.
    func testRoutineCareLogsSurviveUpgradingFromPreVersionedSchemaStore() throws {
        let tempURL = makeTempURL()
        defer { removeStore(at: tempURL) }

        let dates = [
            TestSupport.date(2026, 6, 20),
            TestSupport.date(2026, 6, 22),
            TestSupport.date(2026, 6, 24),
        ]

        do {
            let legacyContainer = try makeLegacyContainer(url: tempURL)
            let legacyContext = ModelContext(legacyContainer)
            for date in dates {
                legacyContext.insert(RoutineCareLog(date: date))
            }
            let pair = try LensPairService.startNewPair(
                name: nil, startDate: TestSupport.date(2026, 6, 1), maximumUses: 60,
                trackingMode: .pair, side: .both, context: legacyContext
            )
            _ = pair
            try legacyContext.save()
        }

        // "Atualiza o app": mesmo arquivo, agora aberto com o schema versionado + plano de
        // migração atuais — a mesma chamada que `AppContainer.shared()` faz de verdade.
        let upgradedContainer = try makeCurrentContainer(url: tempURL)
        let upgradedContext = ModelContext(upgradedContainer)

        let logs = try upgradedContext.fetch(FetchDescriptor<RoutineCareLog>())
        XCTAssertEqual(logs.count, dates.count, "Cuidados diários registrados antes de AppSchemaV1 existir não podem desaparecer ao abrir com a configuração atual")

        XCTAssertEqual(try upgradedContext.fetchCount(FetchDescriptor<LensPair>()), 1, "O par registrado antes da migração também precisa continuar visível")
    }
}
