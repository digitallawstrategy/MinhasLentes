import Foundation
import Observation
import SwiftData

/// Estado e ações do ciclo de vida do estojo (`LensCase`): iniciar/substituir, editar e excluir.
@MainActor
@Observable
final class LensCaseViewModel {
    var presentedError: IdentifiableError?

    func startOrReplaceCase(startDate: Date, intervalDays: Int, notes: String?, settings: AppSettings, context: ModelContext) async {
        do {
            _ = try await LensCaseService.startNewCase(startDate: startDate, intervalDays: intervalDays, notes: notes, settings: settings, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func editCase(_ lensCase: LensCase, startDate: Date, intervalDays: Int, notes: String?, settings: AppSettings, context: ModelContext) async {
        do {
            try await LensCaseService.editCase(lensCase, startDate: startDate, intervalDays: intervalDays, notes: notes, settings: settings, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func deleteCase(_ lensCase: LensCase, context: ModelContext) async {
        do {
            try await LensCaseService.deleteCase(lensCase, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }
}
