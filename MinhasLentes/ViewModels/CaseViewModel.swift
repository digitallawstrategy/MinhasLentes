import Foundation
import Observation
import SwiftData

/// Estado e ações da aba Estojo: registrar limpeza e reagendar as notificações do ciclo.
@MainActor
@Observable
final class CaseViewModel {
    var presentedError: IdentifiableError?
    var showUndoToast = false
    var toastMessage: String?
    private(set) var lastRegisteredCleaning: CaseCleaning?

    private var undoToastTask: Task<Void, Never>?

    /// Quanto tempo o "Desfazer" fica disponível após registrar uma limpeza, antes do toast
    /// sumir sozinho — mesmo padrão usado para desfazer um uso na Home.
    private static let undoToastDuration: Duration = .seconds(5)

    func registerCleaningToday(settings: AppSettings, context: ModelContext) async {
        await registerCleaning(date: Date(), notes: nil, settings: settings, context: context)
    }

    func registerCleaning(date: Date, notes: String?, settings: AppSettings, context: ModelContext) async {
        do {
            let cleaning = try await CaseCleaningService.registerCleaning(date: date, notes: notes, settings: settings, context: context)
            lastRegisteredCleaning = cleaning
            toastMessage = "Limpeza registrada em \(DateFormatting.short.string(from: date))."
            showUndoToast = true
            HapticsService.success()
            scheduleUndoToastAutoDismiss()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func undoLastRegisteredCleaning(settings: AppSettings, context: ModelContext) async {
        guard let cleaning = lastRegisteredCleaning else { return }
        undoToastTask?.cancel()
        do {
            try await CaseCleaningService.deleteCleaning(cleaning, settings: settings, context: context)
            lastRegisteredCleaning = nil
            showUndoToast = false
            HapticsService.success()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível desfazer a limpeza. \(error.localizedDescription)")
        }
    }

    func dismissToast() {
        undoToastTask?.cancel()
        showUndoToast = false
        lastRegisteredCleaning = nil
    }

    private func scheduleUndoToastAutoDismiss() {
        undoToastTask?.cancel()
        undoToastTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoToastDuration)
            guard !Task.isCancelled else { return }
            self?.showUndoToast = false
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

    // MARK: - Ciclo do estojo (LensCase)

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

    // MARK: - Cuidado diário (RoutineCareLog)

    func registerRoutineCareToday(context: ModelContext) {
        registerRoutineCare(date: Date(), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
    }

    func registerRoutineCare(date: Date, discardedSolution: Bool, cleanedCase: Bool, airDried: Bool, notes: String?, context: ModelContext) {
        do {
            try RoutineCareService.registerCare(
                date: date, discardedSolution: discardedSolution, cleanedCase: cleanedCase,
                airDried: airDried, notes: notes, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }
}
