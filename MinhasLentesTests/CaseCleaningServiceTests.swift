import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class CaseCleaningServiceTests: XCTestCase {
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

    func testRegisterCleaningCreatesEntryAndCycle() async throws {
        _ = try await CaseCleaningService.registerCleaning(date: TestSupport.date(2026, 7, 10), notes: nil, settings: settings, context: context)
        XCTAssertEqual(try CaseCleaningService.allCleanings(context: context).count, 1)

        let next = try CaseCleaningService.nextCleaningDate(settings: settings, context: context)
        XCTAssertNotNil(next)
        XCTAssertTrue(Calendar.current.isDate(next!, inSameDayAs: TestSupport.date(2026, 7, 25)))

        let advance = try CaseCleaningService.advanceReminderDate(settings: settings, context: context)
        XCTAssertNotNil(advance)
        XCTAssertTrue(Calendar.current.isDate(advance!, inSameDayAs: TestSupport.date(2026, 7, 22)))
    }

    func testRegisteringNewCleaningRestartsCycle() async throws {
        _ = try await CaseCleaningService.registerCleaning(date: TestSupport.date(2026, 7, 10), notes: nil, settings: settings, context: context)
        _ = try await CaseCleaningService.registerCleaning(date: TestSupport.date(2026, 7, 12), notes: nil, settings: settings, context: context)

        XCTAssertEqual(try CaseCleaningService.allCleanings(context: context).count, 2)

        let last = try CaseCleaningService.lastCleaning(context: context)
        XCTAssertTrue(Calendar.current.isDate(last!.cleaningDate, inSameDayAs: TestSupport.date(2026, 7, 12)))

        let next = try CaseCleaningService.nextCleaningDate(settings: settings, context: context)
        XCTAssertTrue(Calendar.current.isDate(next!, inSameDayAs: TestSupport.date(2026, 7, 27)))
    }

    func testCleaningCycleIndependentOfLensUsage() async throws {
        let pair = try LensPairService.startNewPair(
            name: nil, startDate: TestSupport.date(2026, 7, 10), maximumUses: 60,
            trackingMode: .pair, side: .both, context: context
        )
        for offset in 0..<10 {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: TestSupport.date(2026, 7, 10))!
            _ = try LensPairService.registerUsage(
                for: pair, date: date, side: .both, notes: nil,
                allowMultipleUsesPerDay: false, forceDuplicate: false, context: context
            )
        }
        _ = try await CaseCleaningService.registerCleaning(date: TestSupport.date(2026, 7, 10), notes: nil, settings: settings, context: context)
        let next = try CaseCleaningService.nextCleaningDate(settings: settings, context: context)
        XCTAssertTrue(
            Calendar.current.isDate(next!, inSameDayAs: TestSupport.date(2026, 7, 25)),
            "O prazo do estojo não deve depender da quantidade de usos das lentes"
        )
    }

    func testNoCleaningYieldsNilDates() throws {
        XCTAssertNil(try CaseCleaningService.lastCleaning(context: context))
        XCTAssertNil(try CaseCleaningService.nextCleaningDate(settings: settings, context: context))
    }
}
