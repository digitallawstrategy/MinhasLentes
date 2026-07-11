import XCTest
@testable import MinhasLentes

final class LensInventoryStatisticsServiceTests: XCTestCase {

    func testTotalRemainingQuantityFiltersBySide() {
        let right = LensInventoryItem(brand: "A", model: "X", side: .right, initialQuantity: 5)
        let left = LensInventoryItem(brand: "A", model: "X", side: .left, initialQuantity: 3)
        XCTAssertEqual(LensInventoryStatisticsService.totalRemainingQuantity(items: [right, left]), 8)
        XCTAssertEqual(LensInventoryStatisticsService.totalRemainingQuantity(items: [right, left], side: .right), 5)
    }

    func testNearestExpiryIgnoresItemsWithoutExpiry() {
        let noExpiry = LensInventoryItem(brand: "A", model: "X", initialQuantity: 1)
        let soon = LensInventoryItem(brand: "A", model: "X", expiryDate: TestSupport.date(2026, 8, 1), initialQuantity: 1)
        let later = LensInventoryItem(brand: "A", model: "X", expiryDate: TestSupport.date(2026, 12, 1), initialQuantity: 1)
        XCTAssertEqual(LensInventoryStatisticsService.nearestExpiry(items: [noExpiry, soon, later]), TestSupport.date(2026, 8, 1))
    }

    func testItemsNearExpiryIncludesAlreadyExpired() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let reference = TestSupport.date(2026, 7, 10)
        let expired = LensInventoryItem(brand: "A", model: "X", expiryDate: TestSupport.date(2026, 7, 1), initialQuantity: 1)
        let soon = LensInventoryItem(brand: "A", model: "X", expiryDate: TestSupport.date(2026, 7, 15), initialQuantity: 1)
        let far = LensInventoryItem(brand: "A", model: "X", expiryDate: TestSupport.date(2026, 12, 1), initialQuantity: 1)
        let result = LensInventoryStatisticsService.itemsNearExpiry(items: [expired, soon, far], withinDays: 10, referenceDate: reference, calendar: calendar)
        XCTAssertEqual(Set(result.map(\.id)), Set([expired.id, soon.id]))
    }

    func testIsLowStock() {
        let low = LensInventoryItem(brand: "A", model: "X", initialQuantity: 5)
        low.remainingQuantity = 2
        let ok = LensInventoryItem(brand: "A", model: "X", initialQuantity: 5)
        ok.remainingQuantity = 4
        let exhausted = LensInventoryItem(brand: "A", model: "X", initialQuantity: 5)
        exhausted.remainingQuantity = 0
        exhausted.status = .exhausted
        XCTAssertTrue(LensInventoryStatisticsService.isLowStock(low))
        XCTAssertFalse(LensInventoryStatisticsService.isLowStock(ok))
        XCTAssertFalse(LensInventoryStatisticsService.isLowStock(exhausted))
    }
}
