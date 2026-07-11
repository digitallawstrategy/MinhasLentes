import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class WearSessionServiceTests: XCTestCase {
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = TestSupport.makeContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    private func makePair() throws -> LensPair {
        try LensPairService.startNewPair(
            name: "Par de teste", startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
    }

    func testStartSessionCreatesActiveSession() throws {
        let pair = try makePair()
        let session = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 8), context: context)
        XCTAssertEqual(session.status, .active)
        XCTAssertNil(session.endedAt)
        XCTAssertEqual(session.lensPair?.id, pair.id)
        XCTAssertEqual(try WearSessionService.activeSession(context: context)?.id, session.id)
    }

    func testStartSessionIsIdempotentWhenAlreadyActive() throws {
        let pair = try makePair()
        let first = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 8), context: context)
        let second = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 9), context: context)
        XCTAssertEqual(first.id, second.id, "Iniciar de novo com uma sessão já ativa não deve criar uma segunda")
        XCTAssertEqual(try WearSessionService.allSessions(context: context).count, 1)
    }

    func testEndSessionSetsEndedAtAndStatus() throws {
        let pair = try makePair()
        let session = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 8), context: context)
        try WearSessionService.endSession(session, endedAt: TestSupport.date(2026, 7, 10, hour: 16), context: context)
        XCTAssertEqual(session.status, .ended)
        XCTAssertNotNil(session.endedAt)
        XCTAssertNil(try WearSessionService.activeSession(context: context))
    }

    func testEndSessionIsNoOpWhenAlreadyEnded() throws {
        let pair = try makePair()
        let session = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 8), context: context)
        try WearSessionService.endSession(session, endedAt: TestSupport.date(2026, 7, 10, hour: 16), context: context)
        let endedAtFirst = session.endedAt
        try WearSessionService.endSession(session, endedAt: TestSupport.date(2026, 7, 10, hour: 20), context: context)
        XCTAssertEqual(session.endedAt, endedAtFirst, "Encerrar uma sessão já encerrada não deve sobrescrever o horário original")
    }

    func testDurationComputedFromStartedAndEndedDates() throws {
        let pair = try makePair()
        let session = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 8), context: context)
        try WearSessionService.endSession(session, endedAt: TestSupport.date(2026, 7, 10, hour: 16, minute: 30), context: context)
        XCTAssertEqual(session.duration, 8.5 * 3600, accuracy: 1)
    }

    func testNewSessionAfterPreviousEndedIsAllowed() throws {
        let pair = try makePair()
        let first = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 8), context: context)
        try WearSessionService.endSession(first, endedAt: TestSupport.date(2026, 7, 10, hour: 16), context: context)
        let second = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 11, hour: 8), context: context)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(try WearSessionService.allSessions(context: context).count, 2)
        XCTAssertEqual(try WearSessionService.activeSession(context: context)?.id, second.id)
    }

    func testDeletingPairNullifiesSessionReferenceButKeepsHistory() throws {
        let pair = try makePair()
        let session = try WearSessionService.startSession(for: pair, startedAt: TestSupport.date(2026, 7, 10, hour: 8), context: context)
        try WearSessionService.endSession(session, endedAt: TestSupport.date(2026, 7, 10, hour: 16), context: context)

        try LensPairService.moveToTrash(pair, context: context)
        try LensPairService.permanentlyDeletePair(pair, context: context)

        XCTAssertEqual(try WearSessionService.allSessions(context: context).count, 1, "A sessão deve sobreviver à exclusão do par")
        XCTAssertNil(try WearSessionService.allSessions(context: context).first?.lensPair)
    }
}
