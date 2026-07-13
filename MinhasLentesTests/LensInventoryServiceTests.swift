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

        // Reabastecer de verdade sobe as duas quantidades juntas — "5 de 5", nunca "5 de 1".
        try await LensInventoryService.editItem(
            item, brand: "Nova marca", model: "Novo modelo", prescriptionOD: nil, prescriptionOS: nil,
            side: .right, lot: nil, expiryDate: nil, initialQuantity: 5, remainingQuantity: 5, photoData: nil, notes: "Reposição",
            settings: settings, context: context
        )
        XCTAssertEqual(item.brand, "Nova marca")
        XCTAssertEqual(item.initialQuantity, 5)
        XCTAssertEqual(item.remainingQuantity, 5)
        XCTAssertEqual(item.status, .available, "Adicionar quantidade de volta deve reabrir um item esgotado")
    }

    func testEditItemThrowsWhenRemainingExceedsInitial() async throws {
        let item = try await makeItem(quantity: 1)
        do {
            try await LensInventoryService.editItem(
                item, brand: "Marca", model: "Modelo", prescriptionOD: nil, prescriptionOS: nil,
                side: .both, lot: nil, expiryDate: nil, initialQuantity: 1, remainingQuantity: 5, photoData: nil, notes: nil,
                settings: settings, context: context
            )
            XCTFail("Deveria lançar .invalidQuantities para remaining 5 / total 1")
        } catch LensInventoryService.ServiceError.invalidQuantities {
            // Esperado.
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
        XCTAssertEqual(item.remainingQuantity, 1, "O item não deve ser alterado quando a edição é rejeitada")
    }

    func testEditItemPreservesInvariantAcrossValidEdits() async throws {
        let item = try await makeItem(quantity: 10)

        // Baixar o total reclampa o restante, se preciso.
        try await LensInventoryService.editItem(
            item, brand: "Marca", model: "Modelo", prescriptionOD: nil, prescriptionOS: nil,
            side: .both, lot: nil, expiryDate: nil, initialQuantity: 3, remainingQuantity: 3, photoData: nil, notes: nil,
            settings: settings, context: context
        )
        XCTAssertLessThanOrEqual(item.remainingQuantity, item.initialQuantity)

        // Subir o total de novo continua válido.
        try await LensInventoryService.editItem(
            item, brand: "Marca", model: "Modelo", prescriptionOD: nil, prescriptionOS: nil,
            side: .both, lot: nil, expiryDate: nil, initialQuantity: 8, remainingQuantity: 2, photoData: nil, notes: nil,
            settings: settings, context: context
        )
        XCTAssertEqual(item.initialQuantity, 8)
        XCTAssertEqual(item.remainingQuantity, 2)
        XCTAssertLessThanOrEqual(item.remainingQuantity, item.initialQuantity)
    }

    func testRepairInvalidQuantitiesClampsPreExistingBadData() async throws {
        let item = try await makeItem(quantity: 1)
        // Simula dado inválido gravado antes da validação existir, sem passar por `editItem`.
        item.remainingQuantity = 5
        try context.save()

        let repairedCount = try LensInventoryService.repairInvalidQuantities(context: context)
        XCTAssertEqual(repairedCount, 1)
        XCTAssertEqual(item.remainingQuantity, item.initialQuantity)
    }

    func testRepairInvalidQuantitiesIsNoOpWhenNothingIsInvalid() async throws {
        _ = try await makeItem(quantity: 3)
        let repairedCount = try LensInventoryService.repairInvalidQuantities(context: context)
        XCTAssertEqual(repairedCount, 0)
    }

    func testConsumeSeparateBoxesDecrementsEachByOne() async throws {
        let rightBox = try await makeItem(quantity: 6, side: .right)
        let leftBox = try await makeItem(quantity: 6, side: .left)

        try await LensInventoryService.consume(
            selections: [
                .init(item: rightBox, quantity: 1),
                .init(item: leftBox, quantity: 1),
            ],
            forPairNamed: "Par nº 1",
            context: context
        )

        XCTAssertEqual(rightBox.remainingQuantity, 5)
        XCTAssertEqual(leftBox.remainingQuantity, 5)
    }

    func testConsumeSingleBothBoxDecrementsByTwo() async throws {
        let bothBox = try await makeItem(quantity: 6, side: .both)

        try await LensInventoryService.consume(
            selections: [.init(item: bothBox, quantity: 2)],
            forPairNamed: "Par nº 1",
            context: context
        )

        XCTAssertEqual(bothBox.remainingQuantity, 4)
    }

    func testConsumeSingleBothBoxThrowsAndConsumesNothingWhenInsufficientForBothEyes() async throws {
        let bothBox = try await makeItem(quantity: 1, side: .both)

        do {
            try await LensInventoryService.consume(
                selections: [.init(item: bothBox, quantity: 2)],
                forPairNamed: "Par nº 1",
                context: context
            )
            XCTFail("Deveria lançar .insufficientStock — só há 1 unidade para os 2 necessários")
        } catch LensInventoryService.ServiceError.insufficientStock {
            // Esperado.
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }

        XCTAssertEqual(bothBox.remainingQuantity, 1, "Nada deve ser descontado quando o saldo é insuficiente")
        XCTAssertEqual(bothBox.status, .available)
    }

    func testConsumeIsAllOrNothingWhenOneSelectionHasInsufficientStock() async throws {
        let rightBox = try await makeItem(quantity: 6, side: .right)
        let leftBox = try await makeItem(quantity: 1, side: .left)

        do {
            try await LensInventoryService.consume(
                selections: [
                    .init(item: rightBox, quantity: 1),
                    .init(item: leftBox, quantity: 2),
                ],
                forPairNamed: "Par nº 1",
                context: context
            )
            XCTFail("Deveria lançar .insufficientStock quando a segunda seleção não tem saldo")
        } catch LensInventoryService.ServiceError.insufficientStock {
            // Esperado.
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }

        XCTAssertEqual(rightBox.remainingQuantity, 6, "A primeira seleção não deve ser alterada quando a segunda falha")
        XCTAssertEqual(leftBox.remainingQuantity, 1)
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
