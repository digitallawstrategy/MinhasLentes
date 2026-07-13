import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class RoutineCareServiceTests: XCTestCase {
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = TestSupport.makeContext()
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    func testRegisterCareCreatesEntry() throws {
        let log = try RoutineCareService.registerCare(
            date: TestSupport.date(2026, 7, 10), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context
        )
        XCTAssertEqual(try RoutineCareService.allLogs(context: context).count, 1)
        XCTAssertEqual(try RoutineCareService.lastLog(context: context)?.id, log.id)
    }

    func testRegisterCarePreservesIndividualFlags() throws {
        let log = try RoutineCareService.registerCare(
            date: TestSupport.date(2026, 7, 10), discardedSolution: true, cleanedCase: false, airDried: true, notes: "Sem estojo por perto", context: context
        )
        XCTAssertTrue(log.discardedSolution)
        XCTAssertFalse(log.cleanedCase)
        XCTAssertTrue(log.airDried)
        XCTAssertEqual(log.notes, "Sem estojo por perto")
    }

    func testDeleteCareRemovesEntry() throws {
        let log = try RoutineCareService.registerCare(date: TestSupport.date(2026, 7, 10), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
        try RoutineCareService.deleteCare(log, context: context)
        XCTAssertEqual(try RoutineCareService.allLogs(context: context).count, 0)
    }

    func testEditCareUpdatesFields() throws {
        let log = try RoutineCareService.registerCare(date: TestSupport.date(2026, 7, 10), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
        try RoutineCareService.editCare(
            log, newDate: TestSupport.date(2026, 7, 11), discardedSolution: false, cleanedCase: true, airDried: false, newNotes: "Corrigido", context: context
        )
        XCTAssertTrue(Calendar.current.isDate(log.date, inSameDayAs: TestSupport.date(2026, 7, 11)))
        XCTAssertFalse(log.discardedSolution)
        XCTAssertFalse(log.airDried)
        XCTAssertEqual(log.notes, "Corrigido")
    }

    func testHasCareTodayTrueWhenLogExistsForReferenceDate() throws {
        _ = try RoutineCareService.registerCare(date: TestSupport.date(2026, 7, 10), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
        XCTAssertTrue(try RoutineCareService.hasCareToday(referenceDate: TestSupport.date(2026, 7, 10, hour: 20), context: context))
    }

    func testHasCareTodayFalseWhenNoLogForReferenceDate() throws {
        _ = try RoutineCareService.registerCare(date: TestSupport.date(2026, 7, 9), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
        XCTAssertFalse(try RoutineCareService.hasCareToday(referenceDate: TestSupport.date(2026, 7, 10), context: context))
    }

    func testHasCareTodayChecksAllLogsNotJustFirst() throws {
        // Um log "de hoje" registrado antes de um log futuro (fora de ordem) ainda deve contar —
        // a checagem não pode depender de `allLogs(context:).first`.
        _ = try RoutineCareService.registerCare(date: TestSupport.date(2026, 7, 10), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
        _ = try RoutineCareService.registerCare(date: TestSupport.date(2026, 7, 15), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
        XCTAssertTrue(try RoutineCareService.hasCareToday(referenceDate: TestSupport.date(2026, 7, 10), context: context))
    }

    private var saoPauloCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        return calendar
    }

    func testIsDailyCareReminderDueFalseWhenAlreadyRegisteredRegardlessOfHour() {
        XCTAssertFalse(RoutineCareService.isDailyCareReminderDue(
            referenceDate: TestSupport.date(2026, 7, 10, hour: 23), reminderHour: 10, hasCareToday: true, calendar: saoPauloCalendar
        ))
    }

    func testIsDailyCareReminderDueFalseBeforeReminderHour() {
        XCTAssertFalse(RoutineCareService.isDailyCareReminderDue(
            referenceDate: TestSupport.date(2026, 7, 10, hour: 9), reminderHour: 10, hasCareToday: false, calendar: saoPauloCalendar
        ))
    }

    func testIsDailyCareReminderDueTrueAtOrAfterReminderHourWhenNotRegistered() {
        XCTAssertTrue(RoutineCareService.isDailyCareReminderDue(
            referenceDate: TestSupport.date(2026, 7, 10, hour: 10), reminderHour: 10, hasCareToday: false, calendar: saoPauloCalendar
        ))
        XCTAssertTrue(RoutineCareService.isDailyCareReminderDue(
            referenceDate: TestSupport.date(2026, 7, 10, hour: 15), reminderHour: 10, hasCareToday: false, calendar: saoPauloCalendar
        ))
    }

    func testMultipleLogsSortedMostRecentFirst() throws {
        _ = try RoutineCareService.registerCare(date: TestSupport.date(2026, 7, 10), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
        _ = try RoutineCareService.registerCare(date: TestSupport.date(2026, 7, 11), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
        let logs = try RoutineCareService.allLogs(context: context)
        XCTAssertEqual(logs.count, 2)
        XCTAssertTrue(Calendar.current.isDate(logs.first!.date, inSameDayAs: TestSupport.date(2026, 7, 11)))
    }
}
