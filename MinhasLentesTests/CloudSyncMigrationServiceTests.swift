import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class CloudSyncMigrationServiceTests: XCTestCase {
    var source: ModelContext!
    var destination: ModelContext!

    override func setUp() {
        super.setUp()
        source = TestSupport.makeContext()
        destination = TestSupport.makeContext()
    }

    override func tearDown() {
        source = nil
        destination = nil
        super.tearDown()
    }

    func testHasAnyDataFalseForEmptyContext() throws {
        XCTAssertFalse(try CloudSyncMigrationService.hasAnyData(context: source))
    }

    func testHasAnyDataTrueAfterInsertingSomething() throws {
        source.insert(CaseCleaning(cleaningDate: Date()))
        try source.save()
        XCTAssertTrue(try CloudSyncMigrationService.hasAnyData(context: source))
    }

    func testMigratingEmptySourceCreatesNothing() throws {
        let summary = try CloudSyncMigrationService.migrate(from: source, to: destination)
        XCTAssertEqual(summary, .init())
        XCTAssertFalse(try CloudSyncMigrationService.hasAnyData(context: destination))
    }

    func testMigratesPairWithUsagesAndWearSessionPreservingRelationships() throws {
        let pair = LensPair(
            name: "Par nº 1", sequenceNumber: 1, startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 60, trackingMode: .pair, side: .both
        )
        source.insert(pair)
        let usage = LensUsage(date: TestSupport.date(2026, 7, 2), side: .both, lensPair: pair)
        source.insert(usage)
        let session = WearSession(startedAt: TestSupport.date(2026, 7, 2, hour: 8), lensPair: pair)
        source.insert(session)
        try source.save()

        let summary = try CloudSyncMigrationService.migrate(from: source, to: destination)

        XCTAssertEqual(summary.pairsCopied, 1)
        XCTAssertEqual(summary.usagesCopied, 1)
        XCTAssertEqual(summary.wearSessionsCopied, 1)

        let migratedPairs = try destination.fetch(FetchDescriptor<LensPair>())
        XCTAssertEqual(migratedPairs.count, 1)
        let migratedPair = try XCTUnwrap(migratedPairs.first)
        XCTAssertEqual(migratedPair.id, pair.id, "Preserva o id original")
        XCTAssertEqual(migratedPair.name, "Par nº 1")

        let migratedUsages = try destination.fetch(FetchDescriptor<LensUsage>())
        XCTAssertEqual(migratedUsages.count, 1)
        XCTAssertEqual(migratedUsages.first?.lensPair?.id, migratedPair.id, "Relação remontada para o par novo, não o antigo")

        let migratedSessions = try destination.fetch(FetchDescriptor<WearSession>())
        XCTAssertEqual(migratedSessions.count, 1)
        XCTAssertEqual(migratedSessions.first?.lensPair?.id, migratedPair.id)
    }

    func testMigratesInventoryItemLinkedToPair() throws {
        let item = LensInventoryItem(brand: "Marca", model: "Modelo", initialQuantity: 4)
        source.insert(item)
        let pair = LensPair(
            name: "Par nº 1", sequenceNumber: 1, startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 60, trackingMode: .pair, side: .both, inventoryItem: item
        )
        source.insert(pair)
        try source.save()

        try CloudSyncMigrationService.migrate(from: source, to: destination)

        let migratedPair = try XCTUnwrap(try destination.fetch(FetchDescriptor<LensPair>()).first)
        XCTAssertEqual(migratedPair.inventoryItem?.id, item.id)
    }

    func testMigratesAppointmentLinkedToProfessional() throws {
        let professional = EyeCareProfessional(name: "Dra. Exemplo")
        source.insert(professional)
        let appointment = EyeAppointment(
            date: TestSupport.date(2026, 8, 1), type: .routine, recommendedFollowUpMonths: 12, professional: professional
        )
        source.insert(appointment)
        try source.save()

        try CloudSyncMigrationService.migrate(from: source, to: destination)

        let migratedAppointment = try XCTUnwrap(try destination.fetch(FetchDescriptor<EyeAppointment>()).first)
        XCTAssertEqual(migratedAppointment.professional?.id, professional.id)
    }

    func testMigratesHistoryEventPreservingLooseLensPairID() throws {
        let pair = LensPair(
            name: "Par nº 1", sequenceNumber: 1, startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 60, trackingMode: .pair, side: .both
        )
        source.insert(pair)
        let event = HistoryEvent(eventType: .pairEdited, eventDate: TestSupport.date(2026, 7, 3), lensPairID: pair.id, descriptionText: "Nome alterado")
        source.insert(event)
        try source.save()

        try CloudSyncMigrationService.migrate(from: source, to: destination)

        let migratedEvent = try XCTUnwrap(try destination.fetch(FetchDescriptor<HistoryEvent>()).first)
        let migratedPair = try XCTUnwrap(try destination.fetch(FetchDescriptor<LensPair>()).first)
        XCTAssertEqual(migratedEvent.lensPairID, migratedPair.id, "O id solto continua igual ao do par migrado")
    }

    func testMigratesSettingsPreservingCustomValues() throws {
        let settings = AppSettings()
        settings.allowMultipleUsesPerDay = true
        settings.healthWarningBelowPercent = 55
        source.insert(settings)
        try source.save()

        try CloudSyncMigrationService.migrate(from: source, to: destination)

        let migrated = try XCTUnwrap(try destination.fetch(FetchDescriptor<AppSettings>()).first)
        XCTAssertTrue(migrated.allowMultipleUsesPerDay)
        XCTAssertEqual(migrated.healthWarningBelowPercent, 55)
    }

    /// O ponto que mais importa desta rodada: rodar a migração duas vezes seguidas não duplica
    /// nada, nem quebra — idempotente por checar ids já existentes no destino.
    func testRunningMigrationTwiceDoesNotDuplicate() throws {
        let pair = LensPair(
            name: "Par nº 1", sequenceNumber: 1, startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 60, trackingMode: .pair, side: .both
        )
        source.insert(pair)
        source.insert(LensUsage(date: TestSupport.date(2026, 7, 2), side: .both, lensPair: pair))
        try source.save()

        try CloudSyncMigrationService.migrate(from: source, to: destination)
        let secondSummary = try CloudSyncMigrationService.migrate(from: source, to: destination)

        XCTAssertEqual(secondSummary, .init(), "Nada novo pra copiar na segunda vez")
        XCTAssertEqual(try destination.fetch(FetchDescriptor<LensPair>()).count, 1)
        XCTAssertEqual(try destination.fetch(FetchDescriptor<LensUsage>()).count, 1)
    }

    /// Migrar de novo depois que o destino já tem dados PRÓPRIOS (não vindos desta migração) não
    /// deve sobrescrever nem duplicar o que já está lá.
    func testMigratingWhenDestinationAlreadyHasUnrelatedDataDoesNotOverwrite() throws {
        let ownPair = LensPair(
            name: "Par já no destino", sequenceNumber: 1, startDate: TestSupport.date(2026, 6, 1),
            maximumUses: 60, trackingMode: .pair, side: .both
        )
        destination.insert(ownPair)
        try destination.save()

        let sourcePair = LensPair(
            name: "Par de origem", sequenceNumber: 1, startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 60, trackingMode: .pair, side: .both
        )
        source.insert(sourcePair)
        try source.save()

        try CloudSyncMigrationService.migrate(from: source, to: destination)

        let allPairs = try destination.fetch(FetchDescriptor<LensPair>())
        XCTAssertEqual(allPairs.count, 2, "Os dois pares continuam existindo, nada foi sobrescrito")
        XCTAssertTrue(allPairs.contains { $0.id == ownPair.id })
        XCTAssertTrue(allPairs.contains { $0.id == sourcePair.id })
    }
}
