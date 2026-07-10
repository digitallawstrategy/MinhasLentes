import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class LensCaseServiceTests: XCTestCase {
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

    func testStartNewCaseCreatesActiveCycle() async throws {
        let lensCase = try await LensCaseService.startNewCase(
            startDate: TestSupport.date(2026, 7, 10), intervalDays: 90, notes: nil, settings: settings, context: context
        )
        XCTAssertEqual(lensCase.status, .active)
        XCTAssertNil(lensCase.replacedAt)
        XCTAssertEqual(try LensCaseService.allCases(context: context).count, 1)
        XCTAssertEqual(try LensCaseService.activeCase(context: context)?.id, lensCase.id)
    }

    func testStartingNewCaseReplacesPreviousActiveOne() async throws {
        let first = try await LensCaseService.startNewCase(
            startDate: TestSupport.date(2026, 7, 10), intervalDays: 90, notes: nil, settings: settings, context: context
        )
        let second = try await LensCaseService.startNewCase(
            startDate: TestSupport.date(2026, 10, 1), intervalDays: 90, notes: nil, settings: settings, context: context
        )

        XCTAssertEqual(first.status, .replaced)
        XCTAssertNotNil(first.replacedAt)
        XCTAssertTrue(Calendar.current.isDate(first.replacedAt!, inSameDayAs: TestSupport.date(2026, 10, 1)))
        XCTAssertEqual(second.status, .active)
        XCTAssertEqual(try LensCaseService.allCases(context: context).count, 2)
        XCTAssertEqual(try LensCaseService.activeCase(context: context)?.id, second.id)
    }

    func testNeverMoreThanOneActiveCase() async throws {
        _ = try await LensCaseService.startNewCase(startDate: TestSupport.date(2026, 1, 1), intervalDays: 90, notes: nil, settings: settings, context: context)
        _ = try await LensCaseService.startNewCase(startDate: TestSupport.date(2026, 4, 1), intervalDays: 90, notes: nil, settings: settings, context: context)
        _ = try await LensCaseService.startNewCase(startDate: TestSupport.date(2026, 7, 1), intervalDays: 90, notes: nil, settings: settings, context: context)

        let activeCases = try LensCaseService.allCases(context: context).filter { $0.status == .active }
        XCTAssertEqual(activeCases.count, 1)
    }

    func testEditCaseUpdatesFieldsWithoutChangingStatus() async throws {
        let lensCase = try await LensCaseService.startNewCase(startDate: TestSupport.date(2026, 7, 10), intervalDays: 90, notes: nil, settings: settings, context: context)
        try await LensCaseService.editCase(lensCase, startDate: TestSupport.date(2026, 7, 12), intervalDays: 60, notes: "Corrigido", settings: settings, context: context)

        XCTAssertTrue(Calendar.current.isDate(lensCase.startDate, inSameDayAs: TestSupport.date(2026, 7, 12)))
        XCTAssertEqual(lensCase.intervalDays, 60)
        XCTAssertEqual(lensCase.notes, "Corrigido")
        XCTAssertEqual(lensCase.status, .active)
    }

    func testDeleteActiveCaseLeavesNoneActive() async throws {
        let lensCase = try await LensCaseService.startNewCase(startDate: TestSupport.date(2026, 7, 10), intervalDays: 90, notes: nil, settings: settings, context: context)
        try await LensCaseService.deleteCase(lensCase, context: context)

        XCTAssertNil(try LensCaseService.activeCase(context: context))
        XCTAssertEqual(try LensCaseService.allCases(context: context).count, 0)
    }

    func testDeleteReplacedCaseKeepsOtherActive() async throws {
        let first = try await LensCaseService.startNewCase(startDate: TestSupport.date(2026, 1, 1), intervalDays: 90, notes: nil, settings: settings, context: context)
        let second = try await LensCaseService.startNewCase(startDate: TestSupport.date(2026, 4, 1), intervalDays: 90, notes: nil, settings: settings, context: context)

        try await LensCaseService.deleteCase(first, context: context)

        XCTAssertEqual(try LensCaseService.allCases(context: context).count, 1)
        XCTAssertEqual(try LensCaseService.activeCase(context: context)?.id, second.id)
    }

    func testNextRecommendedReplacementDateComputedFromStart() async throws {
        let lensCase = try await LensCaseService.startNewCase(startDate: TestSupport.date(2026, 7, 10), intervalDays: 90, notes: nil, settings: settings, context: context)
        XCTAssertTrue(Calendar.current.isDate(lensCase.nextRecommendedReplacementDate, inSameDayAs: TestSupport.date(2026, 10, 8)))
    }
}
