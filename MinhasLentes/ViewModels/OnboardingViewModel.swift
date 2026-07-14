import Foundation
import Observation
import SwiftData

/// Conduz o fluxo de primeira abertura (4 passos: boas-vindas, benefícios, configuração inicial e
/// notificações — ver `OnboardingView`): criação do(s) par(es) inicial(is), registro da última
/// limpeza do estojo e solicitação opcional de notificações (com explicação prévia, exibida
/// pela `NotificationPermissionView` antes da chamada ao sistema).
@MainActor
@Observable
final class OnboardingViewModel {
    var startDate = Date()
    var maximumUses = 60
    var trackingMode: TrackingMode = .pair
    var lastCleaningDate = Date()
    var isCompleting = false
    var presentedError: IdentifiableError?

    /// Cria o(s) par(es) inicial(is) e registra a última limpeza do estojo. Não marca
    /// `hasCompletedOnboarding` nem solicita autorização de notificações — isso acontece só ao
    /// final do passo de notificações, via `completeOnboarding(settings:context:)`, para o
    /// usuário nunca "sair" do onboarding (e `ContentView` trocar para as abas principais) antes
    /// de ver a explicação de notificações. Retorna `true` somente se todas as etapas foram
    /// concluídas com sucesso.
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

    /// Marca o onboarding como concluído — chamado uma única vez, ao final do passo de
    /// notificações, independentemente de o usuário ter permitido ou não os avisos.
    func completeOnboarding(settings: AppSettings, context: ModelContext) {
        settings.hasCompletedOnboarding = true
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível concluir o onboarding. \(error.localizedDescription)")
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
