import XCTest
import SwiftData
@testable import MinhasLentes

/// Casos extremos de data/hora: fuso horário, horário de verão, anos bissextos e correções
/// retroativas — todos calculados a partir do calendário e fuso horário informados,
/// nunca de valores fixos.
@MainActor
final class DateEdgeCaseTests: XCTestCase {

    func testDaylightSavingTransitionDoesNotBreakCycle() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        // O horário de verão nos EUA em 2026 inicia em 8 de março.
        let last = TestSupport.date(2026, 3, 1, timeZoneIdentifier: "America/New_York")
        let next = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 15, calendar: calendar)
        XCTAssertTrue(calendar.isDate(next, inSameDayAs: TestSupport.date(2026, 3, 16, timeZoneIdentifier: "America/New_York")))
    }

    func testDifferentTimeZoneCalculatesConsistentCalendarDay() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let last = TestSupport.date(2026, 7, 10, timeZoneIdentifier: "Asia/Tokyo")
        let next = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 15, calendar: tokyo)
        XCTAssertTrue(tokyo.isDate(next, inSameDayAs: TestSupport.date(2026, 7, 25, timeZoneIdentifier: "Asia/Tokyo")))
    }

    func testLeapYearFebruary29() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let last = TestSupport.date(2028, 2, 29)
        let next = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 1, calendar: calendar)
        XCTAssertTrue(calendar.isDate(next, inSameDayAs: TestSupport.date(2028, 3, 1)))
    }

    func testRetroactiveUsageAcrossMonthBoundary() throws {
        let context = TestSupport.makeContext()
        let pair = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 6, 20), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        let usage = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 6, 25), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        XCTAssertEqual(pair.usesCount, 1)
        XCTAssertTrue(Calendar.current.isDate(usage.date, inSameDayAs: TestSupport.date(2026, 6, 25)))
    }

    func testDeletingLastUsageRestoresPreviousLastUsageDate() throws {
        let context = TestSupport.makeContext()
        let pair = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 7, 1), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        _ = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 1), side: .both, notes: nil,
            allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
        )
        let secondUsage = try LensPairService.registerUsage(
            for: pair, date: TestSupport.date(2026, 7, 5), side: .both, notes: nil,
            allowMultipleUsesPerDay: true, forceDuplicate: false, context: context
        )

        XCTAssertTrue(Calendar.current.isDate(pair.lastUsageDate!, inSameDayAs: TestSupport.date(2026, 7, 5)))
        try LensPairService.deleteUsage(secondUsage, context: context)
        XCTAssertTrue(Calendar.current.isDate(pair.lastUsageDate!, inSameDayAs: TestSupport.date(2026, 7, 1)))
    }

    func testChangingLastCleaningRecalculatesCycle() async throws {
        let context = TestSupport.makeContext()
        let settings = AppSettings()
        context.insert(settings)

        _ = try await CaseCleaningService.registerCleaning(date: TestSupport.date(2026, 7, 10), notes: nil, settings: settings, context: context)
        var next = try CaseCleaningService.nextCleaningDate(settings: settings, context: context)
        XCTAssertTrue(Calendar.current.isDate(next!, inSameDayAs: TestSupport.date(2026, 7, 25)))

        let lastCleaning = try XCTUnwrap(CaseCleaningService.lastCleaning(context: context))
        lastCleaning.cleaningDate = TestSupport.date(2026, 7, 1)
        try context.save()

        next = try CaseCleaningService.nextCleaningDate(settings: settings, context: context)
        XCTAssertTrue(Calendar.current.isDate(next!, inSameDayAs: TestSupport.date(2026, 7, 16)))
    }
}
