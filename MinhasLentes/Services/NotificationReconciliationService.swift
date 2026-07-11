import Foundation
import SwiftData
import WidgetKit

/// Ponto único que recalcula e reagenda TODAS as notificações pendentes a partir do estado
/// atual do banco — estojo, solução, itens de estoque, consultas e sessão de uso — e restaura a
/// Live Activity da sessão de uso se for o caso. Chamado tanto nos checks idempotentes de
/// abertura/retomada do app (`ContentView`) quanto depois de uma importação de backup bem
/// sucedida, que só o repovoamento normal por `context.save()` não cobre.
///
/// Também corrige aqui uma sessão de uso órfã (`WearSession.status == .active` sem `lensPair`)
/// — pode acontecer se o par referenciado foi excluído por fora do fluxo normal (ex.: um backup
/// importado com o `lensPairID` da sessão ausente do próprio arquivo). Uma sessão órfã, sem
/// correção, bloquearia para sempre o início de uma sessão nova, já que `WearSessionService
/// .startSession` é idempotente sobre "já existe alguma sessão ativa".
///
/// Falhas de agendamento nunca são apenas descartadas com `try?` sem rastro: a ausência de
/// autorização (estado normal, já visível em Configurações) é a única ignorada em silêncio;
/// qualquer outra falha vira um `HistoryEvent`, para que o problema não fique varrido para
/// baixo do tapete só porque não há uma tela óbvia para mostrar um alerta nesse momento.
@MainActor
enum NotificationReconciliationService {
    static func rebuildAll(context: ModelContext, settings: AppSettings) async {
        if let activeCase = try? LensCaseService.activeCase(context: context) {
            await NotificationManager.shared.cancelLensCaseNotifications()
            await attempt("estojo", context: context) {
                try await NotificationManager.shared.scheduleLensCaseNotifications(
                    startDate: activeCase.startDate, intervalDays: activeCase.intervalDays, settings: settings
                )
            }
            await NotificationManager.shared.refreshOverdueCaseReminder(
                dueDate: activeCase.nextRecommendedReplacementDate, settings: settings
            )
        }

        if let activeSolution = try? CleaningSolutionService.activeSolution(context: context) {
            await NotificationManager.shared.cancelCleaningSolutionNotifications()
            await attempt("solução de limpeza", context: context) {
                try await NotificationManager.shared.scheduleCleaningSolutionNotifications(
                    discardDate: activeSolution.discardDate, settings: settings
                )
            }
            await NotificationManager.shared.refreshOverdueSolutionReminder(
                discardDate: activeSolution.discardDate, settings: settings
            )
        }

        if let items = try? LensInventoryService.availableItems(context: context) {
            for item in items {
                await NotificationManager.shared.cancelLensInventoryNotifications(for: item.id)
                await attempt("estoque (\(item.brand) \(item.model))", context: context) {
                    try await NotificationManager.shared.scheduleLensInventoryNotifications(for: item, settings: settings)
                }
            }
        }

        if let appointments = try? EyeAppointmentService.allAppointments(context: context) {
            for appointment in appointments where appointment.status == .scheduled {
                await NotificationManager.shared.cancelEyeAppointmentNotifications(for: appointment.id)
                await attempt("consulta de \(DateFormatting.short.string(from: appointment.date))", context: context) {
                    try await NotificationManager.shared.scheduleEyeAppointmentNotifications(
                        for: appointment, professionalName: appointment.professional?.name, settings: settings
                    )
                }
            }
        }

        if let session = try? WearSessionService.activeSession(context: context) {
            if let pair = session.lensPair {
                if !LiveActivityService.hasActiveWearingSession() {
                    await LiveActivityService.presentWearingSession(
                        pairID: pair.id, pairName: pair.name, usesRemaining: pair.usesRemaining, maximumUses: pair.maximumUses,
                        wearingSince: session.startedAt, settings: settings
                    )
                }
                await attempt("sessão de uso", context: context) {
                    try await NotificationManager.shared.scheduleWearingExcessiveNotifications(wearingSince: session.startedAt, settings: settings)
                }
                await NotificationManager.shared.refreshWearingExcessiveRepeatReminder(wearingSince: session.startedAt, settings: settings)
            } else {
                // Sessão órfã: nunca deveria existir uma sessão ativa sem par associado. Encerra
                // para não bloquear o início de uma sessão nova para sempre.
                try? WearSessionService.endSession(session, endedAt: Date(), context: context)
                await LiveActivityService.endWearingSession()
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        try? context.save()
    }

    /// Tenta agendar; se falhar por qualquer motivo que não seja falta de autorização (estado
    /// normal, já visível em Configurações), registra no histórico em vez de descartar em
    /// silêncio — sem interromper a reconciliação dos outros domínios.
    private static func attempt(_ label: String, context: ModelContext, _ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; nada a registrar aqui.
        } catch {
            let event = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Não foi possível reagendar os avisos de \(label). \(error.localizedDescription)"
            )
            context.insert(event)
        }
    }
}
