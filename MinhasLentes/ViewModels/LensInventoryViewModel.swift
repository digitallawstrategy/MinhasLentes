import Foundation
import Observation
import SwiftData

/// Estado e ações da tela Estoque de lentes: adicionar, editar e excluir itens comprados.
@MainActor
@Observable
final class LensInventoryViewModel {
    var presentedError: IdentifiableError?

    func addItem(
        brand: String, model: String, prescriptionOD: String?, prescriptionOS: String?, side: LensSide,
        lot: String?, expiryDate: Date?, initialQuantity: Int, photoData: Data?, notes: String?,
        settings: AppSettings, context: ModelContext
    ) async {
        do {
            _ = try await LensInventoryService.addItem(
                brand: brand, model: model, prescriptionOD: prescriptionOD, prescriptionOS: prescriptionOS,
                side: side, lot: lot, expiryDate: expiryDate, initialQuantity: initialQuantity,
                photoData: photoData, notes: notes, settings: settings, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func editItem(
        _ item: LensInventoryItem, brand: String, model: String, prescriptionOD: String?, prescriptionOS: String?,
        side: LensSide, lot: String?, expiryDate: Date?, remainingQuantity: Int, photoData: Data?, notes: String?,
        settings: AppSettings, context: ModelContext
    ) async {
        do {
            try await LensInventoryService.editItem(
                item, brand: brand, model: model, prescriptionOD: prescriptionOD, prescriptionOS: prescriptionOS,
                side: side, lot: lot, expiryDate: expiryDate, remainingQuantity: remainingQuantity,
                photoData: photoData, notes: notes, settings: settings, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func deleteItem(_ item: LensInventoryItem, context: ModelContext) async {
        do {
            try await LensInventoryService.deleteItem(item, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }
}
