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

    func testUsageStatusBands() {
        // Padrões: vida útil alta >= 80%, moderada >= 40%, poucos usos restantes >= 15%, senão limite atingido.
        XCTAssertEqual(
            LensStatisticsService.usageStatus(usesRemaining: 55, maximumUses: 60, goodBelowPercent: 80, warningBelowPercent: 40, criticalBelowPercent: 15),
            .excellent
        )
        XCTAssertEqual(
            LensStatisticsService.usageStatus(usesRemaining: 30, maximumUses: 60, goodBelowPercent: 80, warningBelowPercent: 40, criticalBelowPercent: 15),
            .good
        )
        XCTAssertEqual(
            LensStatisticsService.usageStatus(usesRemaining: 15, maximumUses: 60, goodBelowPercent: 80, warningBelowPercent: 40, criticalBelowPercent: 15),
            .warning
        )
        XCTAssertEqual(
            LensStatisticsService.usageStatus(usesRemaining: 5, maximumUses: 60, goodBelowPercent: 80, warningBelowPercent: 40, criticalBelowPercent: 15),
            .critical
        )
        XCTAssertEqual(
            LensStatisticsService.usageStatus(usesRemaining: 0, maximumUses: 60, goodBelowPercent: 80, warningBelowPercent: 40, criticalBelowPercent: 15),
            .critical,
            "Par no limite deve ser sempre crítico"
        )
    }

    func testAdvanceReminderDateClampsBelowIntervalEvenIfStoredValueIsInvalid() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let last = TestSupport.date(2026, 7, 10)
        // Antecedência (20) maior que o intervalo (10): não pode cair antes da limpeza anterior.
        let advance = LensStatisticsService.advanceReminderDate(lastCleaningDate: last, intervalDays: 10, advanceDays: 20, calendar: calendar)
        let deadline = LensStatisticsService.nextCleaningDate(lastCleaningDate: last, intervalDays: 10, calendar: calendar)
        XCTAssertGreaterThanOrEqual(advance, last)
        XCTAssertLessThan(advance, deadline)
    }

    func testNextCaseReplacementDateIndependentOfCleanings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let start = TestSupport.date(2026, 7, 10)
        let next = LensStatisticsService.nextCaseReplacementDate(startDate: start, intervalDays: 90, calendar: calendar)
        XCTAssertTrue(calendar.isDate(next, inSameDayAs: TestSupport.date(2026, 10, 8)))
    }

    func testSolutionDiscardDateUsesEarlierOfShelfLifeAndPrintedExpiry() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let opened = TestSupport.date(2026, 7, 10)

        // Validade pós-abertura (90 dias) cai antes da validade impressa (bem no futuro).
        let discard1 = LensStatisticsService.solutionDiscardDate(
            openedDate: opened, postOpeningShelfLifeDays: 90, printedExpiryDate: TestSupport.date(2027, 12, 31), calendar: calendar
        )
        XCTAssertTrue(calendar.isDate(discard1, inSameDayAs: TestSupport.date(2026, 10, 8)))

        // Validade impressa cai antes da validade pós-abertura.
        let discard2 = LensStatisticsService.solutionDiscardDate(
            openedDate: opened, postOpeningShelfLifeDays: 90, printedExpiryDate: TestSupport.date(2026, 8, 1), calendar: calendar
        )
        XCTAssertTrue(calendar.isDate(discard2, inSameDayAs: TestSupport.date(2026, 8, 1)))
    }

    func testSolutionDiscardDateWithoutPrintedExpiryUsesShelfLifeOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let opened = TestSupport.date(2026, 7, 10)
        let discard = LensStatisticsService.solutionDiscardDate(
            openedDate: opened, postOpeningShelfLifeDays: 30, printedExpiryDate: nil, calendar: calendar
        )
        XCTAssertTrue(calendar.isDate(discard, inSameDayAs: TestSupport.date(2026, 8, 9)))
    }

    func testCalendarDaySetIgnoresTimeOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let morning = TestSupport.date(2026, 7, 10, hour: 7)
        let night = TestSupport.date(2026, 7, 10, hour: 23)
        let otherDay = TestSupport.date(2026, 7, 11, hour: 7)

        let set = LensStatisticsService.calendarDaySet(from: [morning, night, otherDay], calendar: calendar)
        XCTAssertEqual(set.count, 2, "Manhã e noite do mesmo dia devem colapsar num único dia do calendário")
        XCTAssertTrue(set.contains(calendar.startOfDay(for: morning)))
        XCTAssertTrue(set.contains(calendar.startOfDay(for: otherDay)))
    }

    func testHasUsageOnSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let usage = LensUsage(date: TestSupport.date(2026, 7, 10, hour: 8), side: .both)
        XCTAssertTrue(LensStatisticsService.hasUsage(onSameDayAs: TestSupport.date(2026, 7, 10, hour: 20), in: [usage], calendar: calendar))
        XCTAssertFalse(LensStatisticsService.hasUsage(onSameDayAs: TestSupport.date(2026, 7, 11), in: [usage], calendar: calendar))
    }

    func testAverageIntervalDaysNeedsAtLeastTwoDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        XCTAssertNil(LensStatisticsService.averageIntervalDays(betweenUsageDates: [], calendar: calendar))
        XCTAssertNil(LensStatisticsService.averageIntervalDays(betweenUsageDates: [TestSupport.date(2026, 7, 10)], calendar: calendar))
    }

    func testAverageIntervalDaysComputesMeanSpacing() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        // 10, 12, 14 de julho: dois intervalos de 2 dias, média 2.
        let dates = [
            TestSupport.date(2026, 7, 10),
            TestSupport.date(2026, 7, 14),
            TestSupport.date(2026, 7, 12),
        ]
        let average = LensStatisticsService.averageIntervalDays(betweenUsageDates: dates, calendar: calendar)
        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 2.0, accuracy: 0.0001)
    }

    func testAverageIntervalDaysIgnoresDuplicateUsagesOnSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        // Dois usos no dia 1 (ex.: registrando os dois lados) e um no dia 5: só 2 dias distintos
        // de utilização, separados por 4 dias — a duplicata no dia 1 não pode reduzir a média.
        let dates = [
            TestSupport.date(2026, 7, 1, hour: 8),
            TestSupport.date(2026, 7, 1, hour: 20),
            TestSupport.date(2026, 7, 5),
        ]
        let average = LensStatisticsService.averageIntervalDays(betweenUsageDates: dates, calendar: calendar)
        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 4.0, accuracy: 0.0001)
    }

    func testProjectedDepletionDateNilWithoutAverageOrRemaining() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        XCTAssertNil(LensStatisticsService.projectedDepletionDate(usesRemaining: 5, averageIntervalDays: nil, calendar: calendar))
        XCTAssertNil(LensStatisticsService.projectedDepletionDate(usesRemaining: 0, averageIntervalDays: 2, calendar: calendar))
    }

    func testProjectedDepletionDateProjectsForward() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let reference = TestSupport.date(2026, 7, 10)
        let projected = LensStatisticsService.projectedDepletionDate(
            usesRemaining: 5, averageIntervalDays: 2, referenceDate: reference, calendar: calendar
        )
        XCTAssertNotNil(projected)
        XCTAssertTrue(calendar.isDate(projected!, inSameDayAs: TestSupport.date(2026, 7, 20)))
    }

    func testAverageSessionDurationIgnoresActiveSessions() {
        let ended1 = WearSession(startedAt: TestSupport.date(2026, 7, 10, hour: 8), lensPair: nil)
        ended1.endedAt = TestSupport.date(2026, 7, 10, hour: 10)
        let ended2 = WearSession(startedAt: TestSupport.date(2026, 7, 11, hour: 8), lensPair: nil)
        ended2.endedAt = TestSupport.date(2026, 7, 11, hour: 12)
        let active = WearSession(startedAt: TestSupport.date(2026, 7, 12, hour: 8), lensPair: nil)

        let average = LensStatisticsService.averageSessionDuration(sessions: [ended1, ended2, active])
        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 3 * 3600, accuracy: 1)
    }

    func testAverageSessionDurationNilWithoutCompletedSessions() {
        let active = WearSession(startedAt: TestSupport.date(2026, 7, 12, hour: 8), lensPair: nil)
        XCTAssertNil(LensStatisticsService.averageSessionDuration(sessions: [active]))
    }
}
