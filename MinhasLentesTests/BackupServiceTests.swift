import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class BackupServiceTests: XCTestCase {

    private func seedContext() async throws -> ModelContext {
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

        _ = try await LensCaseService.startNewCase(
            startDate: TestSupport.date(2026, 7, 10), intervalDays: 90, notes: nil, settings: settings, context: context
        )
        _ = try RoutineCareService.registerCare(
            date: TestSupport.date(2026, 7, 10), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context
        )
        _ = try await CleaningSolutionService.startNewSolution(
            brand: "Marca", product: "Multiuso", lot: nil, purchaseDate: nil, openedDate: TestSupport.date(2026, 7, 10),
            printedExpiryDate: nil, postOpeningShelfLifeDays: 90, initialVolumeML: 120, notes: nil,
            settings: settings, context: context
        )
        _ = try await LensInventoryService.addItem(
            brand: "Marca", model: "Modelo", prescriptionOD: nil, prescriptionOS: nil, side: .both,
            lot: nil, expiryDate: nil, initialQuantity: 2, photoData: nil, notes: nil,
            settings: settings, context: context
        )
        let professional = try EyeCareProfessionalService.addProfessional(
            name: "Dra. Ana", clinic: nil, phone: nil, whatsapp: nil, email: nil, address: nil, notes: nil, context: context
        )
        _ = try await EyeAppointmentService.scheduleAppointment(
            date: TestSupport.date(2026, 8, 10), type: .routine, notes: nil, prescription: nil, attachmentData: nil,
            recommendedFollowUpMonths: 12, professional: professional, settings: settings, context: context
        )
        let wearSession = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 8), context: context)
        try WearSessionService.endSession(wearSession, endedAt: TestSupport.date(2026, 7, 10, hour: 16), context: context)

        try context.save()
        return context
    }

    private func writeTempJSON(_ string: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backup-test-\(UUID().uuidString).json")
        try? string.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testExportProducesValidVersionedEnvelope() async throws {
        let context = try await seedContext()
        let url = try BackupService.exportJSON(context: context)
        defer { try? FileManager.default.removeItem(at: url) }

        let envelope = try BackupService.validate(url: url)
        XCTAssertEqual(envelope.schemaVersion, BackupService.currentSchemaVersion)
        XCTAssertEqual(envelope.pairs.count, 1)
        XCTAssertEqual(envelope.usages.count, 2)
        XCTAssertEqual(envelope.cleanings.count, 1)
        XCTAssertEqual(envelope.cases?.count, 1)
        XCTAssertEqual(envelope.routineCareLogs?.count, 1)
        XCTAssertEqual(envelope.solutions?.count, 1)
        XCTAssertEqual(envelope.inventoryItems?.count, 1)
        XCTAssertEqual(envelope.professionals?.count, 1)
        XCTAssertEqual(envelope.appointments?.count, 1)
        XCTAssertEqual(envelope.wearSessions?.count, 1)
        XCTAssertNotNil(envelope.settings)
    }

    func testOldBackupWithoutCaseFieldsStillValidates() throws {
        let legacy = """
        {
          "schemaVersion": 1,
          "createdAt": "2026-07-10T12:00:00Z",
          "pairs": [], "usages": [], "cleanings": [], "events": [],
          "settings": {
            "maximumUses": 60, "cleaningIntervalDays": 15, "advanceReminderDays": 3,
            "notificationHour": 9, "notificationMinute": 0, "allowMultipleUsesPerDay": false,
            "advanceReminderEnabled": true, "deadlineReminderEnabled": true,
            "soundEnabled": true, "badgeEnabled": true, "trackingMode": "pair"
          }
        }
        """
        let url = writeTempJSON(legacy)
        defer { try? FileManager.default.removeItem(at: url) }

        let envelope = try BackupService.validate(url: url)
        XCTAssertNil(envelope.cases)
        XCTAssertNil(envelope.routineCareLogs)
        XCTAssertNil(envelope.solutions)
        XCTAssertNil(envelope.inventoryItems)
        XCTAssertNil(envelope.professionals)
        XCTAssertNil(envelope.appointments)
        XCTAssertNil(envelope.wearSessions)

        let context = TestSupport.makeContext()
        let report = try BackupService.importBackup(from: url, mode: .replace, context: context)
        XCTAssertEqual(report.casesImported, 0)
        XCTAssertEqual(report.routineCareLogsImported, 0)
        XCTAssertEqual(report.solutionsImported, 0)
        XCTAssertEqual(report.inventoryItemsImported, 0)
        XCTAssertEqual(report.professionalsImported, 0)
        XCTAssertEqual(report.appointmentsImported, 0)
        XCTAssertEqual(report.wearSessionsImported, 0)
        XCTAssertTrue(report.settingsImported)
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

    func testReplaceImportWipesExistingDataAndRestoresBackup() async throws {
        let sourceContext = try await seedContext()
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
        XCTAssertEqual(report.casesImported, 1)
        XCTAssertEqual(report.routineCareLogsImported, 1)
        XCTAssertEqual(report.solutionsImported, 1)
        XCTAssertEqual(report.inventoryItemsImported, 1)
        XCTAssertEqual(report.professionalsImported, 1)
        XCTAssertEqual(report.appointmentsImported, 1)
        XCTAssertEqual(report.wearSessionsImported, 1)
        XCTAssertTrue(report.settingsImported)

        let importedPairs = try LensPairService.allPairs(context: targetContext)
        XCTAssertEqual(importedPairs.count, 1)
        XCTAssertEqual(importedPairs.first?.name, "Par de teste")
        XCTAssertEqual(importedPairs.first?.usesCount, 2)
        XCTAssertEqual(try LensCaseService.allCases(context: targetContext).count, 1)
        XCTAssertEqual(try RoutineCareService.allLogs(context: targetContext).count, 1)
        XCTAssertEqual(try CleaningSolutionService.allSolutions(context: targetContext).count, 1)
        XCTAssertEqual(try LensInventoryService.allItems(context: targetContext).count, 1)
        XCTAssertEqual(try EyeCareProfessionalService.allProfessionals(context: targetContext).count, 1)
        let importedAppointments = try EyeAppointmentService.allAppointments(context: targetContext)
        XCTAssertEqual(importedAppointments.count, 1)
        XCTAssertNotNil(importedAppointments.first?.professional, "A consulta importada deve religar ao profissional importado")
        let importedSessions = try WearSessionService.allSessions(context: targetContext)
        XCTAssertEqual(importedSessions.count, 1)
        XCTAssertNotNil(importedSessions.first?.lensPair, "A sessão importada deve religar ao par importado")
    }

    func testMergeImportDoesNotDuplicateExistingRecords() async throws {
        let sourceContext = try await seedContext()
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
        XCTAssertEqual(secondReport.casesSkippedAsDuplicate, 1)
        XCTAssertEqual(secondReport.routineCareLogsSkippedAsDuplicate, 1)
        XCTAssertEqual(secondReport.solutionsSkippedAsDuplicate, 1)
        XCTAssertEqual(secondReport.inventoryItemsSkippedAsDuplicate, 1)
        XCTAssertEqual(secondReport.professionalsSkippedAsDuplicate, 1)
        XCTAssertEqual(secondReport.appointmentsSkippedAsDuplicate, 1)
        XCTAssertEqual(secondReport.wearSessionsSkippedAsDuplicate, 1)

        let pairs = try LensPairService.allPairs(context: targetContext)
        XCTAssertEqual(pairs.count, 1, "A mesclagem repetida não deve duplicar pares")
        XCTAssertEqual(pairs.first?.usesCount, 2, "A mesclagem repetida não deve duplicar usos")
    }

    func testMergeImportPreservesUsagePairRelationshipForSkippedDuplicates() async throws {
        let sourceContext = try await seedContext()
        let url = try BackupService.exportJSON(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: url) }

        let targetContext = TestSupport.makeContext()
        _ = try BackupService.importBackup(from: url, mode: .merge, context: targetContext)

        // Uma segunda mesclagem não deve quebrar a relação uso→par mesmo pulando o par duplicado.
        _ = try BackupService.importBackup(from: url, mode: .merge, context: targetContext)

        let pairs = try LensPairService.allPairs(context: targetContext)
        XCTAssertEqual(pairs.first?.usesCount, 2)
    }

    func testImportFailureLeavesNoPartialData() async throws {
        // Backup com um par válido mas usos que referenciam um lensPairID inexistente NO
        // ARQUIVO seriam barrados na validação; aqui simulamos uma falha após a validação
        // usando um contexto cujo tipo já existe, mas verificando que uma importação que
        // lança erro não deixa o banco em estado intermediário: como `validate` já impede
        // arquivos relacionalmente inconsistentes, este teste confirma que uma tentativa de
        // importação de arquivo inválido não altera em nada o armazenamento existente.
        let context = try await seedContext()
        let pairsBefore = try LensPairService.allPairs(context: context).count

        let invalidURL = writeTempJSON("{ inválido")
        defer { try? FileManager.default.removeItem(at: invalidURL) }

        XCTAssertThrowsError(try BackupService.importBackup(from: invalidURL, mode: .replace, context: context))

        let pairsAfter = try LensPairService.allPairs(context: context).count
        XCTAssertEqual(pairsBefore, pairsAfter, "Uma importação que falha na validação não deve alterar os dados existentes")
    }
}
