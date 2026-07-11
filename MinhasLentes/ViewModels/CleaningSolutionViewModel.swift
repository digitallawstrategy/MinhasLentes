import Foundation
import Observation
import SwiftData

/// Estado e ações da aba Solução: abrir/substituir frasco, editar e excluir registros.
@MainActor
@Observable
final class CleaningSolutionViewModel {
    var presentedError: IdentifiableError?

    func startOrReplaceSolution(
        brand: String, product: String, lot: String?, purchaseDate: Date?, openedDate: Date,
        printedExpiryDate: Date?, postOpeningShelfLifeDays: Int, initialVolumeML: Int?, notes: String?,
        settings: AppSettings, context: ModelContext
    ) async {
        do {
            _ = try await CleaningSolutionService.startNewSolution(
                brand: brand, product: product, lot: lot, purchaseDate: purchaseDate, openedDate: openedDate,
                printedExpiryDate: printedExpiryDate, postOpeningShelfLifeDays: postOpeningShelfLifeDays,
                initialVolumeML: initialVolumeML, notes: notes, settings: settings, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func editSolution(
        _ solution: CleaningSolution, brand: String, product: String, lot: String?, purchaseDate: Date?,
        openedDate: Date, printedExpiryDate: Date?, postOpeningShelfLifeDays: Int,
        initialVolumeML: Int?, remainingVolumeML: Int?, notes: String?, settings: AppSettings, context: ModelContext
    ) async {
        do {
            try await CleaningSolutionService.editSolution(
                solution, brand: brand, product: product, lot: lot, purchaseDate: purchaseDate, openedDate: openedDate,
                printedExpiryDate: printedExpiryDate, postOpeningShelfLifeDays: postOpeningShelfLifeDays,
                initialVolumeML: initialVolumeML, remainingVolumeML: remainingVolumeML, notes: notes,
                settings: settings, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func deleteSolution(_ solution: CleaningSolution, context: ModelContext) async {
        do {
            try await CleaningSolutionService.deleteSolution(solution, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }
}
