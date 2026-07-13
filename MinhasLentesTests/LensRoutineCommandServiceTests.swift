import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class LensRoutineCommandServiceTests: XCTestCase {
    var context: ModelContext!
    var settings: AppSettings!

    override func setUp() {
        super.setUp()
        context = TestSupport.makeContext()
        settings = AppSettings()
        context.insert(settings)
    }

    override func tearDown() {
        context = nil
        settings = nil
        super.tearDown()
    }

    @discardableResult
    private func makeInUsePair(maximumUses: Int = 60) throws -> LensPair {
        try LensPairService.startNewPair(
            name: "Par de teste", startDate: Date(), maximumUses: maximumUses,
            trackingMode: .pair, side: .both, context: context
        )
    }

    // MARK: - startWearing

    func testNoPairInUseReturnsNoPairInUse() async throws {
        let outcome = try await LensRoutineCommandService.startWearing(context: context, settings: settings)
        XCTAssertEqual(outcome, .noPairInUse)
    }

    func testPairInUseNoUsageTodayRegistersAndStartsSession() async throws {
        let pair = try makeInUsePair()
        let outcome = try await LensRoutineCommandService.startWearing(context: context, settings: settings)
        XCTAssertEqual(outcome, .registeredAndStarted)
        XCTAssertEqual(pair.usesCount, 1, "Deve ter registrado o uso de hoje")
        XCTAssertNotNil(try WearSessionService.activeSession(context: context), "Deve ter iniciado a sessão")
    }

    func testPairInUseUsageAlreadyRegisteredTodayDoesNotDuplicateAndStartsSession() async throws {
        let pair = try makeInUsePair()
        try LensPairService.registerUsage(
            for: pair, date: Date(), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        XCTAssertEqual(pair.usesCount, 1)

        let outcome = try await LensRoutineCommandService.startWearing(context: context, settings: settings)

        XCTAssertEqual(outcome, .usageAlreadyRegisteredTodaySessionStarted)
        XCTAssertEqual(pair.usesCount, 1, "Não deve duplicar o uso já registrado hoje")
        XCTAssertNotNil(try WearSessionService.activeSession(context: context))
    }

    /// Comando repetido no mesmo dia, com um encerramento no meio: não deve duplicar o uso na
    /// segunda vez, mesmo depois de a sessão ter sido encerrada e reaberta.
    func testRepeatedCommandAcrossEndAndRestartDoesNotDuplicateUsage() async throws {
        let pair = try makeInUsePair()

        let first = try await LensRoutineCommandService.startWearing(context: context, settings: settings)
        XCTAssertEqual(first, .registeredAndStarted)
        XCTAssertEqual(pair.usesCount, 1)

        _ = try await LensRoutineCommandService.endWearing(context: context)

        let second = try await LensRoutineCommandService.startWearing(context: context, settings: settings)
        XCTAssertEqual(second, .usageAlreadyRegisteredTodaySessionStarted)
        XCTAssertEqual(pair.usesCount, 1, "Segunda chamada no mesmo dia não deve criar um segundo LensUsage")
        XCTAssertNotNil(try WearSessionService.activeSession(context: context), "Deve ter reaberto a sessão")
    }

    /// Comando repetido sem encerrar no meio: idempotente de verdade, nem chega a olhar para uso/par.
    func testRepeatedCommandWhileSessionActiveDoesNotCreateSecondSession() async throws {
        try makeInUsePair()

        let first = try await LensRoutineCommandService.startWearing(context: context, settings: settings)
        XCTAssertEqual(first, .registeredAndStarted)

        let second = try await LensRoutineCommandService.startWearing(context: context, settings: settings)
        XCTAssertEqual(second, .sessionAlreadyActive)

        XCTAssertEqual(try WearSessionService.allSessions(context: context).count, 1, "Não deve existir uma segunda WearSession")
    }

    func testUsageLimitReachedStartsSessionWithoutRegisteringUsage() async throws {
        let pair = try makeInUsePair(maximumUses: 1)
        try LensPairService.registerUsage(
            for: pair, date: Date(), side: .both, notes: nil,
            allowMultipleUsesPerDay: true, forceDuplicate: false, context: context
        )
        XCTAssertTrue(pair.hasReachedLimit)

        let outcome = try await LensRoutineCommandService.startWearing(context: context, settings: settings)

        XCTAssertEqual(outcome, .usageLimitReached)
        XCTAssertEqual(pair.usesCount, 1, "Não deve ter incrementado além do limite")
        XCTAssertNotNil(try WearSessionService.activeSession(context: context), "Sessão inicia mesmo com o limite atingido, mesmo comportamento já existente do diálogo da Home")
    }

    func testAllowMultipleUsesPerDayRegistersAnotherUsageSameDay() async throws {
        let pair = try makeInUsePair()
        settings.allowMultipleUsesPerDay = true
        try LensPairService.registerUsage(
            for: pair, date: Date(), side: .both, notes: nil,
            allowMultipleUsesPerDay: true, forceDuplicate: false, context: context
        )
        XCTAssertEqual(pair.usesCount, 1)

        let outcome = try await LensRoutineCommandService.startWearing(context: context, settings: settings)

        XCTAssertEqual(outcome, .registeredAndStarted, "Com múltiplos usos por dia ligado, não é tratado como duplicidade")
        XCTAssertEqual(pair.usesCount, 2)
    }

    // MARK: - endWearing

    func testEndWearingWithoutActiveSessionReturnsNoActiveSession() async throws {
        try makeInUsePair()
        let outcome = try await LensRoutineCommandService.endWearing(context: context)
        XCTAssertEqual(outcome, .noActiveSession)
    }

    func testEndWearingWithActiveSessionEndsIt() async throws {
        let pair = try makeInUsePair()
        let session = try WearSessionService.startSession(for: pair, startedAt: Date(), context: context)

        let outcome = try await LensRoutineCommandService.endWearing(context: context)

        XCTAssertEqual(outcome, .ended)
        XCTAssertEqual(session.status, .ended)
        XCTAssertNotNil(session.endedAt)
        XCTAssertNil(try WearSessionService.activeSession(context: context))
    }

    /// Encerrar duas vezes seguidas: a segunda é idempotente (no-op), não um erro.
    func testEndWearingTwiceInARowIsIdempotent() async throws {
        let pair = try makeInUsePair()
        try WearSessionService.startSession(for: pair, startedAt: Date(), context: context)

        let first = try await LensRoutineCommandService.endWearing(context: context)
        let second = try await LensRoutineCommandService.endWearing(context: context)

        XCTAssertEqual(first, .ended)
        XCTAssertEqual(second, .noActiveSession)
    }
}
