import XCTest
@testable import MinhasLentes

@MainActor
final class PendingItemsServiceTests: XCTestCase {
    private let referenceDate = TestSupport.date(2026, 7, 10, hour: 15)

    private var saoPauloCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        return calendar
    }

    private func emptyInput(
        hasCareToday: Bool = true,
        dailyCareReminderEnabled: Bool = true,
        dailyCareReminderHour: Int = 10,
        activeWearSession: WearSession? = nil,
        wearingReminderHours: Int = 8,
        lastCleaning: CaseCleaning? = nil,
        activeCase: LensCase? = nil,
        cleaningIntervalDays: Int = 15,
        advanceReminderDays: Int = 3,
        activeSolution: CleaningSolution? = nil,
        nextAppointment: EyeAppointment? = nil,
        expiringInventoryItems: [LensInventoryItem] = []
    ) -> PendingItemsInput {
        PendingItemsInput(
            hasCareToday: hasCareToday,
            dailyCareReminderEnabled: dailyCareReminderEnabled,
            dailyCareReminderHour: dailyCareReminderHour,
            activeWearSession: activeWearSession,
            wearingReminderHours: wearingReminderHours,
            lastCleaning: lastCleaning,
            activeCase: activeCase,
            cleaningIntervalDays: cleaningIntervalDays,
            advanceReminderDays: advanceReminderDays,
            activeSolution: activeSolution,
            nextAppointment: nextAppointment,
            expiringInventoryItems: expiringInventoryItems
        )
    }

    func testEmptyInputProducesEmptyList() {
        let items = PendingItemsService.pendingItems(input: emptyInput(), referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertTrue(items.isEmpty)
    }

    func testShowsDailyCarePendingAfterHourIfNotRegistered() {
        let input = emptyInput(hasCareToday: false, dailyCareReminderHour: 10)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertTrue(items.contains { $0.id == .dailyCare })
    }

    func testDoesNotShowDailyCarePendingIfAlreadyRegisteredToday() {
        let input = emptyInput(hasCareToday: true, dailyCareReminderHour: 10)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertFalse(items.contains { $0.id == .dailyCare })
    }

    func testDoesNotShowDailyCarePendingBeforeReminderHour() {
        let morning = TestSupport.date(2026, 7, 10, hour: 8)
        let input = emptyInput(hasCareToday: false, dailyCareReminderHour: 10)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: morning, calendar: saoPauloCalendar)
        XCTAssertFalse(items.contains { $0.id == .dailyCare })
    }

    func testShowsWearSessionPendingWhenExceedsThreshold() {
        let session = WearSession(startedAt: referenceDate.addingTimeInterval(-9 * 3600), lensPair: nil)
        let input = emptyInput(activeWearSession: session, wearingReminderHours: 8)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertTrue(items.contains { $0.id == .wearSession })
    }

    func testDoesNotShowWearSessionPendingUnderThreshold() {
        let session = WearSession(startedAt: referenceDate.addingTimeInterval(-2 * 3600), lensPair: nil)
        let input = emptyInput(activeWearSession: session, wearingReminderHours: 8)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertFalse(items.contains { $0.id == .wearSession })
    }

    func testShowsCaseReplacementPendingWhenNearOrOverdue() {
        // intervalDays 90, iniciado há 89 dias -> substituição amanhã, dentro da janela de aviso.
        let startDate = TestSupport.date(2026, 4, 12)
        let lensCase = LensCase(startDate: startDate, intervalDays: 90)
        let input = emptyInput(activeCase: lensCase, advanceReminderDays: 3)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertTrue(items.contains { $0.id == .caseReplacementDue })
    }

    func testDoesNotShowCaseReplacementPendingWhenFarInTheFuture() {
        let lensCase = LensCase(startDate: referenceDate, intervalDays: 90)
        let input = emptyInput(activeCase: lensCase, advanceReminderDays: 3)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertFalse(items.contains { $0.id == .caseReplacementDue })
    }

    func testShowsCaseCleaningPendingWhenNear() {
        let lensCase = LensCase(startDate: referenceDate, intervalDays: 90)
        // Última limpeza há 14 dias, intervalo de 15 -> próxima limpeza amanhã.
        let lastCleaning = CaseCleaning(cleaningDate: TestSupport.date(2026, 6, 26))
        let input = emptyInput(lastCleaning: lastCleaning, activeCase: lensCase, cleaningIntervalDays: 15, advanceReminderDays: 3)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertTrue(items.contains { $0.id == .caseCleaningDue })
    }

    func testShowsSolutionPendingWhenNearDiscard() {
        let solution = CleaningSolution(
            brand: "Marca", product: "Produto", openedDate: TestSupport.date(2026, 6, 12), postOpeningShelfLifeDays: 30
        )
        let input = emptyInput(advanceReminderDays: 3, activeSolution: solution)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertTrue(items.contains { $0.id == .solutionDiscardNear })
    }

    func testDoesNotShowSolutionPendingWhenFarFromDiscard() {
        let solution = CleaningSolution(
            brand: "Marca", product: "Produto", openedDate: referenceDate, postOpeningShelfLifeDays: 90
        )
        let input = emptyInput(advanceReminderDays: 3, activeSolution: solution)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertFalse(items.contains { $0.id == .solutionDiscardNear })
    }

    func testShowsInventoryExpiryPendingWhenItemsPresent() {
        let item = LensInventoryItem(
            brand: "Marca", model: "Modelo", prescriptionOD: nil, prescriptionOS: nil, side: .both,
            lot: nil, expiryDate: TestSupport.date(2026, 7, 15), initialQuantity: 2, photoData: nil, notes: nil
        )
        let input = emptyInput(expiringInventoryItems: [item])
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertTrue(items.contains { $0.id == .inventoryExpiry })
    }

    func testShowsAppointmentPendingWhenNear() {
        let appointment = EyeAppointment(
            date: TestSupport.date(2026, 7, 12), type: .routine, recommendedFollowUpMonths: 12, professional: nil
        )
        let input = emptyInput(advanceReminderDays: 3, nextAppointment: appointment)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertTrue(items.contains { $0.id == .appointment })
    }

    func testDoesNotShowAppointmentPendingWhenFarInTheFuture() {
        let appointment = EyeAppointment(
            date: TestSupport.date(2026, 9, 12), type: .routine, recommendedFollowUpMonths: 12, professional: nil
        )
        let input = emptyInput(advanceReminderDays: 3, nextAppointment: appointment)
        let items = PendingItemsService.pendingItems(input: input, referenceDate: referenceDate, calendar: saoPauloCalendar)
        XCTAssertFalse(items.contains { $0.id == .appointment })
    }
}
