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
    private(set) var lastRegisteredUsages: [LensUsage] = []

    private typealias RegistrationRequest = (pair: LensPair, date: Date, side: LensSide, notes: String?)
    private var pendingRegistrations: [RegistrationRequest] = []
    private var undoToastTask: Task<Void, Never>?

    /// Quanto tempo o "Desfazer" fica disponível após um registro, antes do toast sumir sozinho.
    private static let undoToastDuration: Duration = .seconds(5)

    // MARK: - Registro de uso

    func registerUsageToday(for pair: LensPair, side: LensSide, settings: AppSettings, context: ModelContext) {
        registerBatch(requests: [(pair, Date(), side, nil)], settings: settings, context: context)
    }

    func registerUsage(for pair: LensPair, date: Date, side: LensSide, notes: String?, settings: AppSettings, context: ModelContext) {
        registerBatch(requests: [(pair, date, side, notes)], settings: settings, context: context)
    }

    /// Registra o uso de hoje em todos os pares em uso de uma vez. É tudo ou nada: se algum
    /// par tiver um uso duplicado no dia, uma única confirmação cobre o lote inteiro — cancelar
    /// não deixa nenhum par parcialmente alterado (diferente do comportamento anterior, em que
    /// cancelar a duplicidade do par B não desfazia o que já tinha sido gravado no par A).
    func registerUsageForAllInUsePairs(_ pairs: [LensPair], settings: AppSettings, context: ModelContext) {
        let now = Date()
        let requests: [RegistrationRequest] = pairs
            .filter { !$0.hasReachedLimit }
            .map { ($0, now, $0.side, nil) }
        registerBatch(requests: requests, settings: settings, context: context)
    }

    func confirmDuplicateRegistration(settings: AppSettings, context: ModelContext) {
        let pending = pendingRegistrations
        pendingRegistrations = []
        registerBatch(requests: pending, settings: settings, context: context, forceAll: true)
    }

    func cancelDuplicateRegistration() {
        pendingRegistrations = []
        showDuplicateConfirmation = false
    }

    private func registerBatch(
        requests: [RegistrationRequest],
        settings: AppSettings,
        context: ModelContext,
        forceAll: Bool = false
    ) {
        guard !requests.isEmpty else { return }

        // Pré-checagens somente-leitura, antes de qualquer gravação: garantem que o lote é
        // tudo-ou-nada. Se qualquer par já estiver no limite, nada é registrado em nenhum par.
        if requests.contains(where: { $0.pair.hasReachedLimit }) {
            showLimitReachedAlert = true
            HapticsService.error()
            return
        }

        if !forceAll && !settings.allowMultipleUsesPerDay {
            let hasDuplicate = requests.contains { request in
                LensStatisticsService.hasUsage(onSameDayAs: request.date, in: request.pair.usages ?? [])
            }
            if hasDuplicate {
                pendingRegistrations = requests
                showDuplicateConfirmation = true
                return
            }
        }

        var registered: [LensUsage] = []
        do {
            for request in requests {
                let usage = try LensPairService.registerUsage(
                    for: request.pair,
                    date: request.date,
                    side: request.side,
                    notes: request.notes,
                    allowMultipleUsesPerDay: settings.allowMultipleUsesPerDay,
                    forceDuplicate: forceAll,
                    context: context
                )
                registered.append(usage)
            }
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: "Não foi possível registrar o uso. \(error.localizedDescription)")
            return
        }

        for request in requests {
            LiveActivityService.showUsageConfirmation(
                pairID: request.pair.id,
                pairName: request.pair.name,
                usesRemaining: request.pair.usesRemaining,
                maximumUses: request.pair.maximumUses
            )
        }

        lastRegisteredUsages = registered
        toastMessage = registered.count > 1
            ? "Uso registrado em \(registered.count) pares."
            : "Uso registrado em \(DateFormatting.short.string(from: registered.first?.date ?? Date()))."
        showUndoToast = true
        HapticsService.success()
        scheduleUndoToastAutoDismiss()
    }

    func undoLastRegisteredUsage(context: ModelContext) {
        guard !lastRegisteredUsages.isEmpty else { return }
        undoToastTask?.cancel()
        do {
            for usage in lastRegisteredUsages {
                try LensPairService.deleteUsage(usage, context: context)
            }
            lastRegisteredUsages = []
            showUndoToast = false
            HapticsService.success()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível desfazer o registro. \(error.localizedDescription)")
        }
    }

    func dismissToast() {
        undoToastTask?.cancel()
        showUndoToast = false
        lastRegisteredUsages = []
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
        asReserve: Bool,
        context: ModelContext
    ) {
        do {
            try LensPairService.startNewPair(
                name: name,
                startDate: startDate,
                maximumUses: maximumUses,
                trackingMode: trackingMode,
                side: side,
                asReserve: asReserve,
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

    func promoteToInUse(_ pair: LensPair, context: ModelContext) {
        do {
            try LensPairService.promoteToInUse(pair, context: context)
            HapticsService.success()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível ativar o par. \(error.localizedDescription)")
        }
    }

    func demoteToReserve(_ pair: LensPair, context: ModelContext) {
        do {
            try LensPairService.demoteToReserve(pair, context: context)
            HapticsService.lightImpact()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível mover o par para reserva. \(error.localizedDescription)")
        }
    }

    // MARK: - Sessão "Estou usando as lentes"

    private(set) var wearingSessionPairID: UUID?

    /// Deve ser chamado ao abrir a tela Início: a Live Activity sobrevive a reabertura do app
    /// (e até ao encerramento forçado), então o estado do botão precisa refletir a realidade.
    func refreshWearingSessionState() {
        wearingSessionPairID = LiveActivityService.activeWearingSessionPairID()
    }

    func toggleWearingSession(for pair: LensPair, settings: AppSettings) {
        Task {
            if wearingSessionPairID == pair.id {
                await LiveActivityService.endWearingSession()
            } else {
                let started = await LiveActivityService.startWearingSession(
                    pairID: pair.id,
                    pairName: pair.name,
                    usesRemaining: pair.usesRemaining,
                    maximumUses: pair.maximumUses,
                    settings: settings
                )
                if started {
                    HapticsService.success()
                }
            }
            refreshWearingSessionState()
        }
    }
}
