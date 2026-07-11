import Foundation
import Observation
import SwiftData

/// Estado e ações do cuidado rotineiro pós-remoção (`RoutineCareLog`): registrar o de hoje, com
/// detalhes, ou desfazer o último registro — mesmo padrão de `CaseCleaningViewModel`, para que
/// toda ação de registro do dia a dia possa ser corrigida com um toque, sem exceção.
@MainActor
@Observable
final class RoutineCareViewModel {
    var presentedError: IdentifiableError?
    var showUndoToast = false
    var toastMessage: String?
    private(set) var lastRegisteredLog: RoutineCareLog?

    private var undoToastTask: Task<Void, Never>?

    /// Quanto tempo o "Desfazer" fica disponível após um registro, antes do toast sumir sozinho
    /// — mesmo padrão usado para uso e limpeza periódica.
    private static let undoToastDuration: Duration = .seconds(5)

    func registerRoutineCareToday(context: ModelContext) {
        registerRoutineCare(date: Date(), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
    }

    func registerRoutineCare(date: Date, discardedSolution: Bool, cleanedCase: Bool, airDried: Bool, notes: String?, context: ModelContext) {
        do {
            let log = try RoutineCareService.registerCare(
                date: date, discardedSolution: discardedSolution, cleanedCase: cleanedCase,
                airDried: airDried, notes: notes, context: context
            )
            lastRegisteredLog = log
            toastMessage = "Cuidado diário registrado em \(DateFormatting.short.string(from: date))."
            showUndoToast = true
            HapticsService.success()
            scheduleUndoToastAutoDismiss()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func undoLastRegisteredRoutineCare(context: ModelContext) {
        guard let log = lastRegisteredLog else { return }
        undoToastTask?.cancel()
        do {
            try RoutineCareService.deleteCare(log, context: context)
            lastRegisteredLog = nil
            showUndoToast = false
            HapticsService.success()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível desfazer o cuidado diário. \(error.localizedDescription)")
        }
    }

    func dismissToast() {
        undoToastTask?.cancel()
        showUndoToast = false
        lastRegisteredLog = nil
    }

    private func scheduleUndoToastAutoDismiss() {
        undoToastTask?.cancel()
        undoToastTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoToastDuration)
            guard !Task.isCancelled else { return }
            self?.showUndoToast = false
        }
    }
}
