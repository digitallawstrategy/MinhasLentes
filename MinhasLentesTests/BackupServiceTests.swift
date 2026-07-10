import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class BackupServiceTests: XCTestCase {

    private func seedContext() throws -> ModelContext {
        let context = TestSupport.makeContext()
        let settings = AppSettings()
        context.insert(settings)

        let pair = try LensPairService.startNewPair(
            name: "Par de teste", startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        _ = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: "Primeira vez",
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        _ = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 11), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        let cleaning = CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 10))
        context.insert(cleaning)
        try context.save()
        return context
    }

    private func writeTempJSON(_ string: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backup-test-\(UUID().uuidString).json")
        try? string.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testExportProducesValidVersionedEnvelope() throws {
        let context = try seedContext()
        let url = try BackupService.exportJSON(context: context)
        defer { try? FileManager.default.removeItem(at: url) }

        let envelope = try BackupService.validate(url: url)
        XCTAssertEqual(envelope.schemaVersion, BackupService.currentSchemaVersion)
        XCTAssertEqual(envelope.pairs.count, 1)
        XCTAssertEqual(envelope.usages.count, 2)
        XCTAssertEqual(envelope.cleanings.count, 1)
        XCTAssertNotNil(envelope.settings)
    }

    func testValidateRejectsCorruptedFile() throws {
        let url = writeTempJSON("isto não é um JSON válido {{{")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try BackupService.validate(url: url)) { error in
            guard case BackupService.BackupError.decodingFailed = error else {
                return XCTFail("Esperava decodingFailed, obteve \(error)")
            }
        }
    }

    func testValidateRejectsUnsupportedSchemaVersion() throws {
        let future = """
        {
          "schemaVersion": 999,
          "createdAt": "2026-07-10T12:00:00Z",
          "pairs": [], "usages": [], "cleanings": [], "events": [], "settings": null
        }
        """
        let url = writeTempJSON(future)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try BackupService.validate(url: url)) { error in
            guard case BackupService.BackupError.unsupportedSchemaVersion(let version) = error else {
                return XCTFail("Esperava unsupportedSchemaVersion, obteve \(error)")
            }
            XCTAssertEqual(version, 999)
        }
    }

    func testValidateRejectsOrphanUsageReference() throws {
        let knownPairID = UUID().uuidString
        let orphan = """
        {
          "schemaVersion": 1,
          "createdAt": "2026-07-10T12:00:00Z",
          "pairs": [
            {"id": "\(knownPairID)", "name": "Par nº 1", "sequenceNumber": 1, "startDate": "2026-07-10T12:00:00Z", "endDate": null, "maximumUses": 60, "status": "active", "discardReason": null, "notes": null, "trackingMode": "pair", "side": "both", "createdAt": "2026-07-10T12:00:00Z"}
          ],
          "usages": [
            {"id": "\(UUID().uuidString)", "lensPairID": "\(UUID().uuidString)", "date": "2026-07-10T12:00:00Z", "side": "both", "notes": null, "createdAt": "2026-07-10T12:00:00Z"}
          ],
          "cleanings": [], "events": [], "settings": null
        }
        """
        let url = writeTempJSON(orphan)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try BackupService.validate(url: url)) { error in
            guard case BackupService.BackupError.invalidFile = error else {
                return XCTFail("Esperava invalidFile, obteve \(error)")
            }
        }
    }

    func testReplaceImportWipesExistingDataAndRestoresBackup() throws {
        let sourceContext = try seedContext()
        let url = try BackupService.exportJSON(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: url) }

        let targetContext = TestSupport.makeContext()
        // Dados pré-existentes que devem ser removidos pelo modo "substituir".
        let preexisting = try LensPairService.startNewPair(
            name: "Par antigo", startDate: TestSupport.date(2020, 1, 1), maximumUses: 10,
            trackingMode: .pair, side: .both, context: targetContext
        )
        _ = preexisting

        let report = try BackupService.importBackup(from: url, mode: .replace, context: targetContext)
        XCTAssertEqual(report.pairsImported, 1)
        XCTAssertEqual(report.usagesImported, 2)
        XCTAssertEqual(report.cleaningsImported, 1)
        XCTAssertTrue(report.settingsImported)

        let importedPairs = try LensPairService.allPairs(context: targetContext)
        XCTAssertEqual(importedPairs.count, 1)
        XCTAssertEqual(importedPairs.first?.name, "Par de teste")
        XCTAssertEqual(importedPairs.first?.usesCount, 2)
    }

    func testMergeImportDoesNotDuplicateExistingRecords() throws {
        let sourceContext = try seedContext()
        let url = try BackupService.exportJSON(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: url) }

        // Importa uma primeira vez em um contexto vazio (equivalente a restaurar em aparelho novo).
        let targetContext = TestSupport.makeContext()
        let firstReport = try BackupService.importBackup(from: url, mode: .merge, context: targetContext)
        XCTAssertEqual(firstReport.pairsImported, 1)
        XCTAssertEqual(firstReport.usagesImported, 2)

        // Importa o mesmo arquivo novamente: nada deve ser duplicado.
        let secondReport = try BackupService.importBackup(from: url, mode: .merge, context: targetContext)
        XCTAssertEqual(secondReport.pairsImported, 0)
        XCTAssertEqual(secondReport.pairsSkippedAsDuplicate, 1)
        XCTAssertEqual(secondReport.usagesImported, 0)
        XCTAssertEqual(secondReport.usagesSkippedAsDuplicate, 2)
        XCTAssertEqual(secondReport.cleaningsSkippedAsDuplicate, 1)

        let pairs = try LensPairService.allPairs(context: targetContext)
        XCTAssertEqual(pairs.count, 1, "A mesclagem repetida não deve duplicar pares")
        XCTAssertEqual(pairs.first?.usesCount, 2, "A mesclagem repetida não deve duplicar usos")
    }

    func testMergeImportPreservesUsagePairRelationshipForSkippedDuplicates() throws {
        let sourceContext = try seedContext()
        let url = try BackupService.exportJSON(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: url) }

        let targetContext = TestSupport.makeContext()
        _ = try BackupService.importBackup(from: url, mode: .merge, context: targetContext)

        // Uma segunda mesclagem não deve quebrar a relação uso→par mesmo pulando o par duplicado.
        _ = try BackupService.importBackup(from: url, mode: .merge, context: targetContext)

        let pairs = try LensPairService.allPairs(context: targetContext)
        XCTAssertEqual(pairs.first?.usesCount, 2)
    }

    func testImportFailureLeavesNoPartialData() throws {
        // Backup com um par válido mas usos que referenciam um lensPairID inexistente NO
        // ARQUIVO seriam barrados na validação; aqui simulamos uma falha após a validação
        // usando um contexto cujo tipo já existe, mas verificando que uma importação que
        // lança erro não deixa o banco em estado intermediário: como `validate` já impede
        // arquivos relacionalmente inconsistentes, este teste confirma que uma tentativa de
        // importação de arquivo inválido não altera em nada o armazenamento existente.
        let context = try seedContext()
        let pairsBefore = try LensPairService.allPairs(context: context).count

        let invalidURL = writeTempJSON("{ inválido")
        defer { try? FileManager.default.removeItem(at: invalidURL) }

        XCTAssertThrowsError(try BackupService.importBackup(from: invalidURL, mode: .replace, context: context))

        let pairsAfter = try LensPairService.allPairs(context: context).count
        XCTAssertEqual(pairsBefore, pairsAfter, "Uma importação que falha na validação não deve alterar os dados existentes")
    }
}
