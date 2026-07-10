import Foundation
import Observation
import SwiftData

/// Estado e ações da aba Estojo: registrar limpeza e reagendar as notificações do ciclo.
@MainActor
@Observable
final class CaseViewModel {
    var presentedError: IdentifiableError?

    func registerCleaningToday(settings: AppSettings, context: ModelContext) async {
        await registerCleaning(date: Date(), notes: nil, settings: settings, context: context)
    }

    func registerCleaning(date: Date, notes: String?, settings: AppSettings, context: ModelContext) async {
        do {
            _ = try await CaseCleaningService.registerCleaning(date: date, notes: notes, settings: settings, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func deleteCleaning(_ cleaning: CaseCleaning, settings: AppSettings, context: ModelContext) async {
        do {
            try await CaseCleaningService.deleteCleaning(cleaning, settings: settings, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func editCleaning(_ cleaning: CaseCleaning, newDate: Date, newNotes: String?, settings: AppSettings, context: ModelContext) async {
        do {
            try await CaseCleaningService.editCleaning(cleaning, newDate: newDate, newNotes: newNotes, settings: settings, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }
}
