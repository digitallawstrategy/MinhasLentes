import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class LensPairServiceTests: XCTestCase {
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = TestSupport.makeContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    func testStartNewPairAssignsSequentialNumbersAndDefaultName() throws {
        let pair1 = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        XCTAssertEqual(pair1.sequenceNumber, 1)
        XCTAssertEqual(pair1.name, "Par nº 1")

        try LensPairService.finishPair(pair1, endDate: TestSupport.date(2026, 9, 1), reason: .other, notes: nil, context: context)
        let pair2 = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 9, 1), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        XCTAssertEqual(pair2.sequenceNumber, 2)
        XCTAssertEqual(pair2.name, "Par nº 2")
    }

    func testStartingNewPairDemotesPreviousInUsePairToReserveOnSameSide() throws {
        let pair1 = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        let pair2 = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 8, 1), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        XCTAssertEqual(pair1.status, .reserve, "O par anterior deve virar reserva, nunca ser encerrado automaticamente")
        XCTAssertEqual(pair2.status, .inUse)
        XCTAssertEqual(try LensPairService.inUsePairs(context: context).count, 1)
        XCTAssertEqual(try LensPairService.reservePairs(context: context).count, 1)

        try LensPairService.finishPair(pair1, endDate: TestSupport.date(2026, 8, 5), reason: .other, notes: nil, context: context)
        XCTAssertEqual(pair1.status, .finished)
        XCTAssertEqual(try LensPairService.inUsePairs(context: context).count, 1)
    }

    func testStartNewPairAsReserveDoesNotAffectCurrentInUsePair() throws {
        let pair1 = try makePair()
        let pair2 = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 8, 1), maximumUses: 60,
            trackingMode: .pair, side: .both, asReserve: true, context: context
        )
        XCTAssertEqual(pair1.status, .inUse)
        XCTAssertEqual(pair2.status, .reserve)
        XCTAssertEqual(try LensPairService.inUsePairs(context: context).count, 1)
    }

    func testPromoteToInUseDemotesCurrentInUsePairOnSameSide() throws {
        let pair1 = try makePair()
        let pair2 = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 8, 1), maximumUses: 60,
            trackingMode: .pair, side: .both, asReserve: true, context: context
        )
        try LensPairService.promoteToInUse(pair2, context: context)
        XCTAssertEqual(pair1.status, .reserve)
        XCTAssertEqual(pair2.status, .inUse)
    }

    func testDemoteToReserveLeavesSideWithoutInUsePair() throws {
        let pair = try makePair()
        try LensPairService.demoteToReserve(pair, context: context)
        XCTAssertEqual(pair.status, .reserve)
        XCTAssertEqual(try LensPairService.inUsePairs(context: context).count, 0)
    }

    func testNormalizeInUseInvariantKeepsOnlyEarliestInUsePerSide() throws {
        // Simula dados de uma versão anterior ao conceito de reserva: dois pares "em uso" no
        // mesmo lado ao mesmo tempo.
        let pair1 = try makePair()
        let pair2 = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 8, 1), maximumUses: 60,
            trackingMode: .pair, side: .both, asReserve: true, context: context
        )
        pair2.status = .inUse
        try context.save()
        XCTAssertEqual(try LensPairService.inUsePairs(context: context).count, 2, "Pré-condição do teste: estado inconsistente simulado")

        try LensPairService.normalizeInUseInvariant(context: context)

        XCTAssertEqual(pair1.status, .inUse, "O par mais antigo deve permanecer em uso")
        XCTAssertEqual(pair2.status, .reserve)
        XCTAssertEqual(try LensPairService.inUsePairs(context: context).count, 1)
    }

    func testReopenPairRestoresAsReserveWithoutLosingUsageHistory() throws {
        let pair = try makePair()
        _ = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        try LensPairService.finishPair(pair, endDate: TestSupport.date(2026, 7, 20), reason: .other, notes: nil, context: context)
        XCTAssertEqual(pair.status, .finished)

        try LensPairService.reopenPair(pair, context: context)
        XCTAssertEqual(pair.status, .reserve, "Reabrir não deve substituir automaticamente o que já estiver em uso")
        XCTAssertNil(pair.endDate)
        XCTAssertNil(pair.discardReasonValue)
        XCTAssertEqual(pair.usesCount, 1, "Reabrir não deve apagar os usos já registrados")
    }

    func testDeletePairRemovesItAndItsUsages() throws {
        let pair = try makePair()
        _ = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        try LensPairService.deletePair(pair, context: context)
        XCTAssertEqual(try LensPairService.allPairs(context: context).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LensUsage>()).count, 0)
    }

    func testEditPairUpdatesNameStartDateAndMaximumUses() throws {
        let pair = try makePair()
        try LensPairService.editPair(pair, name: "Reserva", startDate: TestSupport.date(2026, 6, 1), maximumUses: 30, context: context)
        XCTAssertEqual(pair.name, "Reserva")
        XCTAssertTrue(Calendar.current.isDate(pair.startDate, inSameDayAs: TestSupport.date(2026, 6, 1)))
        XCTAssertEqual(pair.maximumUses, 30)
    }

    func testRegisterUsageIncrementsCountAndDecrementsRemaining() throws {
        let pair = try makePair()
        try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        XCTAssertEqual(pair.usesCount, 1)
        XCTAssertEqual(pair.usesRemaining, 59)
    }

    func testDuplicateUsageSameDayThrowsUnlessAllowedOrForced() throws {
        let pair = try makePair()
        try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10, hour: 8), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )

        XCTAssertThrowsError(try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10, hour: 20), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )) { error in
            XCTAssertEqual(error as? LensPairService.ServiceError, .duplicateUsageOnDate)
        }
        XCTAssertEqual(pair.usesCount, 1)

        try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10, hour: 20), side: .both, notes: nil,
            allowMultipleUsesPerDay: true, forceDuplicate: false, context: context
        )
        XCTAssertEqual(pair.usesCount, 2)
    }

    func testForceDuplicateBypassesCheck() throws {
        let pair = try makePair()
        try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: true, context: context
        )
        XCTAssertEqual(pair.usesCount, 2)
    }

    func testLimitReachedPreventsNewUsageAndCounterNeverNegative() throws {
        let pair = try makePair(maximumUses: 2)
        try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 11), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        XCTAssertTrue(pair.hasReachedLimit)
        XCTAssertEqual(pair.usesRemaining, 0)

        XCTAssertThrowsError(try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 12), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )) { error in
            XCTAssertEqual(error as? LensPairService.ServiceError, .limitReached)
        }
        XCTAssertEqual(pair.usesCount, 2)
        XCTAssertEqual(pair.usesRemaining, 0)
    }

    func testDeleteUsageReturnsOneUseToCounter() throws {
        let pair = try makePair()
        let usage = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        XCTAssertEqual(pair.usesRemaining, 59)
        try LensPairService.deleteUsage(usage, context: context)
        XCTAssertEqual(pair.usesCount, 0)
        XCTAssertEqual(pair.usesRemaining, 60)
    }

    func testEditUsageDoesNotCreateDuplicate() throws {
        let pair = try makePair()
        let usage = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        try LensPairService.editUsage(usage, newDate: TestSupport.date(2026, 7, 15), newSide: .both, newNotes: "Ajustado", context: context)
        XCTAssertEqual(pair.usesCount, 1)
        XCTAssertTrue(Calendar.current.isDate(usage.date, inSameDayAs: TestSupport.date(2026, 7, 15)))
    }

    func testUndoLastUsage() throws {
        let pair = try makePair()
        try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        XCTAssertTrue(try LensPairService.undoLastUsage(for: pair, context: context))
        XCTAssertEqual(pair.usesCount, 0)
        XCTAssertFalse(try LensPairService.undoLastUsage(for: pair, context: context), "Não deve haver nada para desfazer")
    }

    func testFinishPairPreservesHistoryAndSetsReason() throws {
        let pair = try makePair()
        _ = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        try LensPairService.finishPair(pair, endDate: TestSupport.date(2026, 7, 20), reason: .damaged, notes: "Rasgou", context: context)

        XCTAssertEqual(pair.status, .finished)
        XCTAssertEqual(pair.usesCount, 1, "Encerrar não deve apagar o histórico de usos")
        XCTAssertEqual(pair.discardReasonValue, .damaged)
    }

    func testNewPairDoesNotAlterPreviousPair() throws {
        let pair1 = try makePair()
        _ = try LensPairService.registerUsage(
            for: pair1, date: TestSupport.date(2026, 7, 10), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        try LensPairService.finishPair(pair1, endDate: TestSupport.date(2026, 8, 1), reason: .other, notes: nil, context: context)

        let pair2 = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 8, 1), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        _ = try LensPairService.registerUsage(
            for: pair2, date: TestSupport.date(2026, 8, 2), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )

        XCTAssertEqual(pair1.usesCount, 1)
        XCTAssertEqual(pair2.usesCount, 1)
        XCTAssertEqual(pair1.status, .finished)
    }

    func testIndividualModeTracksRightAndLeftIndependently() throws {
        let right = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
            trackingMode: .individual, side: .right, context: context
        )
        let left = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
            trackingMode: .individual, side: .left, context: context
        )

        _ = try LensPairService.registerUsage(for: right, date: TestSupport.date(2026, 7, 10), side: .right, notes: nil, allowMultipleUsesPerDay: false, forceDuplicate: false, context: context)
        _ = try LensPairService.registerUsage(for: right, date: TestSupport.date(2026, 7, 11), side: .right, notes: nil, allowMultipleUsesPerDay: false, forceDuplicate: false, context: context)
        _ = try LensPairService.registerUsage(for: left, date: TestSupport.date(2026, 7, 10), side: .left, notes: nil, allowMultipleUsesPerDay: false, forceDuplicate: false, context: context)

        XCTAssertEqual(right.usesCount, 2)
        XCTAssertEqual(left.usesCount, 1)
        XCTAssertEqual(right.usesRemaining, 58)
        XCTAssertEqual(left.usesRemaining, 59)
        XCTAssertEqual(try LensPairService.inUsePairs(context: context).count, 2)
    }

    func testRetroactiveDateRegistration() throws {
        let pair = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 1, 1), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        let usage = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 1, 5), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        XCTAssertTrue(Calendar.current.isDate(usage.date, inSameDayAs: TestSupport.date(2026, 1, 5)))
    }

    // MARK: - Auxiliar

    private func makePair(maximumUses: Int = 60) throws -> LensPair {
        try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 7, 10), maximumUses: maximumUses,
            trackingMode: .pair, side: .both, context: context
        )
    }
}
