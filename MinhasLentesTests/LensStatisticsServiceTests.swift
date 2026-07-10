import XCTest
@testable import MinhasLentes

final class LensStatisticsServiceTests: XCTestCase {

    func testExampleFromSpecification() {
        // limite: 60 utilizações; uso registrado em 10/07/2026; usos realizados: 1; usos restantes: 59.
        XCTAssertEqual(LensStatisticsService.usesRemaining(usesCount: 1, maximumUses: 60), 59)
    }

    func testUsesRemainingNeverNegative() {
        XCTAssertEqual(LensStatisticsService.usesRemaining(usesCount: 65, maximumUses: 60), 0)
        XCTAssertEqual(LensStatisticsService.usesRemaining(usesCount: 0, maximumUses: 60), 60)
    }

    func testHasReachedLimit() {
        XCTAssertTrue(LensStatisticsService.hasReachedLimit(usesCount: 60, maximumUses: 60))
        XCTAssertTrue(LensStatisticsService.hasReachedLimit(usesCount: 61, maximumUses: 60))
        XCTAssertFalse(LensStatisticsService.hasReachedLimit(usesCount: 59, maximumUses: 60))
    }

    func testLifeUsedFraction() {
        XCTAssertEqual(LensStatisticsService.lifeUsedFraction(usesCount: 30, maximumUses: 60), 0.5, accuracy: 0.0001)
        XCTAssertEqual(LensStatisticsService.lifeUsedFraction(usesCount: 90, maximumUses: 60), 1.0, accuracy: 0.0001)
        XCTAssertEqual(LensStatisticsService.lifeUsedFraction(usesCount: 0, maximumUses: 0), 0, accuracy: 0.0001)
    }

    func testNextCleaningDateIndependentOfUsage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let last = TestSupport.date(2026, 7, 10)
        let next = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 15, calendar: calendar)
        XCTAssertTrue(calendar.isDate(next, inSameDayAs: TestSupport.date(2026, 7, 25)))
    }

    func testAdvanceReminderDateBeforeDeadline() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let last = TestSupport.date(2026, 7, 10)
        let advance = LensStatisticsService.advanceReminderDate(lastCleaningDate: last, intervalDays: 15, advanceDays: 3, calendar: calendar)
        let deadline = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 15, calendar: calendar)
        XCTAssertTrue(calendar.isDate(advance, inSameDayAs: TestSupport.date(2026, 7, 22)))
        XCTAssertLessThan(advance, deadline)
    }

    func testMonthRollover() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let last = TestSupport.date(2026, 7, 25)
        let next = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 15, calendar: calendar)
        XCTAssertTrue(calendar.isDate(next, inSameDayAs: TestSupport.date(2026, 8, 9)))
    }

    func testYearRollover() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let last = TestSupport.date(2026, 12, 25)
        let next = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 15, calendar: calendar)
        XCTAssertTrue(calendar.isDate(next, inSameDayAs: TestSupport.date(2027, 1, 9)))
    }

    func testLeapYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let last = TestSupport.date(2028, 2, 20)
        let next = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 15, calendar: calendar)
        XCTAssertTrue(calendar.isDate(next, inSameDayAs: TestSupport.date(2028, 3, 6)))
    }

    func testHasUsageOnSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let usage = LensUsage(date: TestSupport.date(2026, 7, 10, hour: 8), side: .both)
        XCTAssertTrue(LensStatisticsService.hasUsage(onSameDayAs: TestSupport.date(2026, 7, 10, hour: 20), in: [usage], calendar: calendar))
        XCTAssertFalse(LensStatisticsService.hasUsage(onSameDayAs: TestSupport.date(2026, 7, 11), in: [usage], calendar: calendar))
    }
}
