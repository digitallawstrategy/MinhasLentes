import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class CleaningSolutionServiceTests: XCTestCase {
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

    private func makeSolution(openedDate: Date, printedExpiryDate: Date? = nil, shelfLifeDays: Int = 90) async throws -> CleaningSolution {
        try await CleaningSolutionService.startNewSolution(
            brand: "Marca", product: "Multiuso", lot: "L123", purchaseDate: nil, openedDate: openedDate,
            printedExpiryDate: printedExpiryDate, postOpeningShelfLifeDays: shelfLifeDays, initialVolumeML: 120,
            notes: nil, settings: settings, context: context
        )
    }

    func testStartNewSolutionCreatesActiveBottle() async throws {
        let solution = try await makeSolution(openedDate: TestSupport.date(2026, 7, 10))
        XCTAssertEqual(solution.status, .active)
        XCTAssertNil(solution.finishedAt)
        XCTAssertEqual(try CleaningSolutionService.allSolutions(context: context).count, 1)
        XCTAssertEqual(try CleaningSolutionService.activeSolution(context: context)?.id, solution.id)
        XCTAssertEqual(solution.remainingVolumeML, 120, "Volume restante deve começar igual ao volume inicial")
    }

    func testOpeningNewBottleFinishesPreviousActiveOne() async throws {
        let first = try await makeSolution(openedDate: TestSupport.date(2026, 7, 10))
        let second = try await makeSolution(openedDate: TestSupport.date(2026, 10, 1))

        XCTAssertEqual(first.status, .finished)
        XCTAssertNotNil(first.finishedAt)
        XCTAssertTrue(Calendar.current.isDate(first.finishedAt!, inSameDayAs: TestSupport.date(2026, 10, 1)))
        XCTAssertEqual(second.status, .active)
        XCTAssertEqual(try CleaningSolutionService.allSolutions(context: context).count, 2)
        XCTAssertEqual(try CleaningSolutionService.activeSolution(context: context)?.id, second.id)
    }

    func testNeverMoreThanOneActiveSolution() async throws {
        _ = try await makeSolution(openedDate: TestSupport.date(2026, 1, 1))
        _ = try await makeSolution(openedDate: TestSupport.date(2026, 4, 1))
        _ = try await makeSolution(openedDate: TestSupport.date(2026, 7, 1))

        let activeSolutions = try CleaningSolutionService.allSolutions(context: context).filter { $0.status == .active }
        XCTAssertEqual(activeSolutions.count, 1)
    }

    func testEditSolutionUpdatesFieldsWithoutChangingStatus() async throws {
        let solution = try await makeSolution(openedDate: TestSupport.date(2026, 7, 10))
        try await CleaningSolutionService.editSolution(
            solution, brand: "Outra marca", product: "Outro produto", lot: "L999", purchaseDate: nil,
            openedDate: TestSupport.date(2026, 7, 12), printedExpiryDate: nil, postOpeningShelfLifeDays: 60,
            initialVolumeML: 120, remainingVolumeML: 90, notes: "Corrigido", settings: settings, context: context
        )

        XCTAssertEqual(solution.brand, "Outra marca")
        XCTAssertEqual(solution.postOpeningShelfLifeDays, 60)
        XCTAssertEqual(solution.remainingVolumeML, 90)
        XCTAssertEqual(solution.notes, "Corrigido")
        XCTAssertEqual(solution.status, .active)
    }

    func testDeleteActiveSolutionLeavesNoneActive() async throws {
        let solution = try await makeSolution(openedDate: TestSupport.date(2026, 7, 10))
        try await CleaningSolutionService.deleteSolution(solution, context: context)

        XCTAssertNil(try CleaningSolutionService.activeSolution(context: context))
        XCTAssertEqual(try CleaningSolutionService.allSolutions(context: context).count, 0)
    }

    func testDiscardDateComputedFromOpenedDateAndShelfLife() async throws {
        let solution = try await makeSolution(openedDate: TestSupport.date(2026, 7, 10), shelfLifeDays: 90)
        XCTAssertTrue(Calendar.current.isDate(solution.discardDate, inSameDayAs: TestSupport.date(2026, 10, 8)))
    }

    func testDiscardDateRespectsEarlierPrintedExpiry() async throws {
        let solution = try await makeSolution(
            openedDate: TestSupport.date(2026, 7, 10), printedExpiryDate: TestSupport.date(2026, 8, 1), shelfLifeDays: 90
        )
        XCTAssertTrue(Calendar.current.isDate(solution.discardDate, inSameDayAs: TestSupport.date(2026, 8, 1)))
    }
}
