import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class LensInventoryServiceTests: XCTestCase {
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

    private func makeItem(quantity: Int = 3, side: LensSide = .both, expiryDate: Date? = nil) async throws -> LensInventoryItem {
        try await LensInventoryService.addItem(
            brand: "Marca", model: "Modelo", prescriptionOD: "-2.00", prescriptionOS: "-1.75", side: side,
            lot: "L1", expiryDate: expiryDate, initialQuantity: quantity, photoData: nil, notes: nil,
            settings: settings, context: context
        )
    }

    func testAddItemCreatesAvailableEntry() async throws {
        let item = try await makeItem()
        XCTAssertEqual(item.status, .available)
        XCTAssertEqual(item.remainingQuantity, 3)
        XCTAssertEqual(try LensInventoryService.allItems(context: context).count, 1)
        XCTAssertEqual(try LensInventoryService.availableItems(context: context).count, 1)
    }

    func testMultipleItemsCanBeActiveSimultaneously() async throws {
        _ = try await makeItem()
        _ = try await makeItem()
        _ = try await makeItem()
        XCTAssertEqual(try LensInventoryService.availableItems(context: context).count, 3, "Diferente de estojo/solução, vários itens podem estar disponíveis ao mesmo tempo")
    }

    func testConsumeOneDecrementsQuantity() async throws {
        let item = try await makeItem(quantity: 3)
        try await LensInventoryService.consumeOne(item, forPairNamed: "Par nº 1", context: context)
        XCTAssertEqual(item.remainingQuantity, 2)
        XCTAssertEqual(item.status, .available)
    }

    func testConsumeOneMarksExhaustedAtZero() async throws {
        let item = try await makeItem(quantity: 1)
        try await LensInventoryService.consumeOne(item, forPairNamed: "Par nº 1", context: context)
        XCTAssertEqual(item.remainingQuantity, 0)
        XCTAssertEqual(item.status, .exhausted)
        XCTAssertEqual(try LensInventoryService.availableItems(context: context).count, 0)
    }

    func testConsumeOneNeverGoesNegative() async throws {
        let item = try await makeItem(quantity: 0)
        item.status = .exhausted
        try context.save()
        try await LensInventoryService.consumeOne(item, forPairNamed: "Par nº 1", context: context)
        XCTAssertEqual(item.remainingQuantity, 0)
    }

    func testEditItemUpdatesFieldsAndReopensExhaustedWhenQuantityAddedBack() async throws {
        let item = try await makeItem(quantity: 1)
        try await LensInventoryService.consumeOne(item, forPairNamed: "Par nº 1", context: context)
        XCTAssertEqual(item.status, .exhausted)

        try await LensInventoryService.editItem(
            item, brand: "Nova marca", model: "Novo modelo", prescriptionOD: nil, prescriptionOS: nil,
            side: .right, lot: nil, expiryDate: nil, remainingQuantity: 5, photoData: nil, notes: "Reposição",
            settings: settings, context: context
        )
        XCTAssertEqual(item.brand, "Nova marca")
        XCTAssertEqual(item.remainingQuantity, 5)
        XCTAssertEqual(item.status, .available, "Adicionar quantidade de volta deve reabrir um item esgotado")
    }

    func testDeleteItemRemovesIt() async throws {
        let item = try await makeItem()
        try await LensInventoryService.deleteItem(item, context: context)
        XCTAssertEqual(try LensInventoryService.allItems(context: context).count, 0)
    }

    func testIsExpiredReflectsExpiryDate() async throws {
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let future = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let expired = try await makeItem(expiryDate: past)
        let valid = try await makeItem(expiryDate: future)
        XCTAssertTrue(expired.isExpired)
        XCTAssertFalse(valid.isExpired)
    }
}
