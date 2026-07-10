import Foundation
import Observation
import SwiftData

/// Conduz o fluxo de primeira abertura: criação do(s) par(es) inicial(is), registro da última
/// limpeza do estojo e solicitação opcional de notificações (com explicação prévia, exibida
/// pela `NotificationPermissionView` antes da chamada ao sistema).
@MainActor
@Observable
final class OnboardingViewModel {
    var startDate = Date()
    var maximumUses = 60
    var trackingMode: TrackingMode = .pair
    var lastCleaningDate = Date()
    var wantsNotifications = true
    var isCompleting = false
    var presentedError: IdentifiableError?

    /// Cria o(s) par(es) inicial(is) e registra a última limpeza do estojo. Não solicita
    /// autorização de notificações — isso é feito separadamente, após a tela explicativa.
    /// Retorna `true` somente se todas as etapas foram concluídas com sucesso.
    @discardableResult
    func createInitialData(settings: AppSettings, context: ModelContext) async -> Bool {
        isCompleting = true
        defer { isCompleting = false }

        settings.maximumUses = maximumUses
        settings.trackingMode = trackingMode
        do {
            try context.save()

            switch trackingMode {
            case .pair:
                try LensPairService.startNewPair(
                    name: nil,
                    startDate: startDate,
                    maximumUses: maximumUses,
                    trackingMode: .pair,
                    side: .both,
                    context: context
                )
            case .individual:
                try LensPairService.startNewPair(
                    name: nil,
                    startDate: startDate,
                    maximumUses: maximumUses,
                    trackingMode: .individual,
                    side: .right,
                    context: context
                )
                try LensPairService.startNewPair(
                    name: nil,
                    startDate: startDate,
                    maximumUses: maximumUses,
                    trackingMode: .individual,
                    side: .left,
                    context: context
                )
            }

            _ = try await CaseCleaningService.registerCleaning(date: lastCleaningDate, notes: nil, settings: settings, context: context)
            return true
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível concluir a configuração inicial. \(error.localizedDescription)")
            return false
        }
    }

    /// Solicita a autorização de notificações ao iOS e agenda o primeiro ciclo de lembretes.
    func requestNotificationsAndSchedule(settings: AppSettings) async {
        let granted = await NotificationManager.shared.requestAuthorization()
        guard granted else { return }
        do {
            try await NotificationManager.shared.scheduleCaseCleaningNotifications(lastCleaningDate: lastCleaningDate, settings: settings)
        } catch {
            presentedError = IdentifiableError(message: "As notificações foram autorizadas, mas não foi possível agendar o primeiro lembrete. \(error.localizedDescription)")
        }
    }
}
