import Foundation
import Observation
import SwiftData

/// Estado e ações da tela Início: registrar uso com um toque, desfazer o último lançamento
/// e orquestrar o encerramento/início de pares.
///
/// Toda falha de persistência é capturada e exposta em `presentedError` para que a View
/// mostre um alerta compreensível — nenhuma operação crítica falha silenciosamente.
@MainActor
@Observable
final class HomeViewModel {
    var showDuplicateConfirmation = false
    var showLimitReachedAlert = false
    var showUndoToast = false
    var toastMessage: String?
    var presentedError: IdentifiableError?
    private(set) var lastRegisteredUsage: LensUsage?

    private var pendingRegistration: (pair: LensPair, date: Date, side: LensSide, notes: String?)?
    private var undoToastTask: Task<Void, Never>?

    /// Quanto tempo o "Desfazer" fica disponível após um registro, antes do toast sumir sozinho.
    private static let undoToastDuration: Duration = .seconds(5)

    // MARK: - Registro de uso

    func registerUsageToday(for pair: LensPair, side: LensSide, settings: AppSettings, context: ModelContext) {
        register(pair: pair, date: Date(), side: side, notes: nil, settings: settings, context: context, force: false)
    }

    func registerUsage(for pair: LensPair, date: Date, side: LensSide, notes: String?, settings: AppSettings, context: ModelContext) {
        register(pair: pair, date: date, side: side, notes: notes, settings: settings, context: context, force: false)
    }

    func confirmDuplicateRegistration(settings: AppSettings, context: ModelContext) {
        guard let pending = pendingRegistration else { return }
        register(pair: pending.pair, date: pending.date, side: pending.side, notes: pending.notes, settings: settings, context: context, force: true)
        pendingRegistration = nil
    }

    func cancelDuplicateRegistration() {
        pendingRegistration = nil
        showDuplicateConfirmation = false
    }

    private func register(
        pair: LensPair,
        date: Date,
        side: LensSide,
        notes: String?,
        settings: AppSettings,
        context: ModelContext,
        force: Bool
    ) {
        do {
            let usage = try LensPairService.registerUsage(
                for: pair,
                date: date,
                side: side,
                notes: notes,
                allowMultipleUsesPerDay: settings.allowMultipleUsesPerDay,
                forceDuplicate: force,
                context: context
            )
            lastRegisteredUsage = usage
            toastMessage = "Uso registrado em \(DateFormatting.short.string(from: date))."
            showUndoToast = true
            HapticsService.success()
            scheduleUndoToastAutoDismiss()
        } catch LensPairService.ServiceError.duplicateUsageOnDate {
            pendingRegistration = (pair, date, side, notes)
            showDuplicateConfirmation = true
        } catch LensPairService.ServiceError.limitReached {
            showLimitReachedAlert = true
            HapticsService.error()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: "Não foi possível registrar o uso. \(error.localizedDescription)")
        }
    }

    func undoLastRegisteredUsage(context: ModelContext) {
        guard let usage = lastRegisteredUsage else { return }
        undoToastTask?.cancel()
        do {
            try LensPairService.deleteUsage(usage, context: context)
            lastRegisteredUsage = nil
            showUndoToast = false
            HapticsService.success()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível desfazer o registro. \(error.localizedDescription)")
        }
    }

    func dismissToast() {
        undoToastTask?.cancel()
        showUndoToast = false
        lastRegisteredUsage = nil
    }

    private func scheduleUndoToastAutoDismiss() {
        undoToastTask?.cancel()
        undoToastTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoToastDuration)
            guard !Task.isCancelled else { return }
            self?.showUndoToast = false
        }
    }

    // MARK: - Ciclo de vida do par

    func finishPair(_ pair: LensPair, endDate: Date, reason: DiscardReason, notes: String?, context: ModelContext) {
        do {
            try LensPairService.finishPair(pair, endDate: endDate, reason: reason, notes: notes, context: context)
            HapticsService.lightImpact()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível encerrar o par. \(error.localizedDescription)")
        }
    }

    func startNewPair(
        name: String?,
        startDate: Date,
        maximumUses: Int,
        trackingMode: TrackingMode,
        side: LensSide,
        context: ModelContext
    ) {
        do {
            try LensPairService.startNewPair(
                name: name,
                startDate: startDate,
                maximumUses: maximumUses,
                trackingMode: trackingMode,
                side: side,
                context: context
            )
            HapticsService.success()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível iniciar um novo par. \(error.localizedDescription)")
        }
    }

    func editPair(_ pair: LensPair, name: String, startDate: Date, maximumUses: Int, context: ModelContext) {
        do {
            try LensPairService.editPair(pair, name: name, startDate: startDate, maximumUses: maximumUses, context: context)
            HapticsService.lightImpact()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar as alterações do par. \(error.localizedDescription)")
        }
    }

    func reopenPair(_ pair: LensPair, context: ModelContext) {
        do {
            try LensPairService.reopenPair(pair, context: context)
            HapticsService.success()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível reabrir o par. \(error.localizedDescription)")
        }
    }

    func deletePair(_ pair: LensPair, context: ModelContext) {
        do {
            try LensPairService.deletePair(pair, context: context)
            HapticsService.lightImpact()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível excluir o par. \(error.localizedDescription)")
        }
    }
}
