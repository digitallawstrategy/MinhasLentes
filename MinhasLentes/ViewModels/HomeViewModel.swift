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
        showUndoToast = false
        lastRegisteredUsage = nil
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

    func rename(_ pair: LensPair, to newName: String, context: ModelContext) {
        do {
            try LensPairService.renamePair(pair, newName: newName, context: context)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível renomear o par. \(error.localizedDescription)")
        }
    }
}
