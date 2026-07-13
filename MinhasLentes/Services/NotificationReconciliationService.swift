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
/// Nenhuma falha aqui — nem de leitura (buscar o estojo/solução/estoque/consultas/sessão
/// ativos), nem de agendamento, nem do `save()` final — é descartada com `try?` sem rastro. A
/// ausência de autorização de notificações (estado normal, já visível em Configurações) é a
/// única ignorada em silêncio de propósito; qualquer outra falha vira um `HistoryEvent`, para
/// que o problema não fique varrido para baixo do tapete só porque não há uma tela óbvia para
/// mostrar um alerta nesse momento. Única exceção: se o próprio `save()` final falhar (mesmo
/// após nova tentativa), não há como registrar isso de forma durável — nesse caso extremo, cai
/// para o console (ver comentário no fim de `rebuildAll`).
@MainActor
enum NotificationReconciliationService {
    static func rebuildAll(context: ModelContext, settings: AppSettings) async {
        // Corrige, de forma idempotente, itens de estoque com `remainingQuantity > initialQuantity`
        // gravados antes da validação existir em `LensInventoryService.editItem` — roda a cada
        // reconciliação, sem custo perceptível quando não há nada para corrigir.
        _ = attemptFetch("o reparo do estoque", context: context, { try LensInventoryService.repairInvalidQuantities(context: context) })

        if let activeCase = attemptFetch("o estojo", context: context, { try LensCaseService.activeCase(context: context) }) {
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

        if let activeSolution = attemptFetch("a solução de limpeza", context: context, { try CleaningSolutionService.activeSolution(context: context) }) {
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

        if let items = attemptFetch("o estoque", context: context, { try LensInventoryService.availableItems(context: context) }) {
            for item in items {
                await NotificationManager.shared.cancelLensInventoryNotifications(for: item.id)
                await attempt("estoque (\(item.brand) \(item.model))", context: context) {
                    try await NotificationManager.shared.scheduleLensInventoryNotifications(for: item, settings: settings)
                }
            }
        }

        if let appointments = attemptFetch("as consultas", context: context, { try EyeAppointmentService.allAppointments(context: context) }) {
            for appointment in appointments where appointment.status == .scheduled {
                await NotificationManager.shared.cancelEyeAppointmentNotifications(for: appointment.id)
                await attempt("consulta de \(DateFormatting.short.string(from: appointment.date))", context: context) {
                    try await NotificationManager.shared.scheduleEyeAppointmentNotifications(
                        for: appointment, professionalName: appointment.professional?.name, settings: settings
                    )
                }
            }
        }

        if let session = attemptFetch("a sessão de uso", context: context, { try WearSessionService.activeSession(context: context) }) {
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
                do {
                    try WearSessionService.endSession(session, endedAt: Date(), context: context)
                } catch {
                    log("Não foi possível encerrar automaticamente a sessão de uso órfã. \(error.localizedDescription)", context: context)
                }
                await LiveActivityService.endWearingSession()
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        do {
            try context.save()
        } catch {
            do {
                try context.save()
            } catch {
                // Se o próprio `save()` está falhando (mesmo após uma nova tentativa), não há
                // como registrar isto de forma durável: o insert de um `HistoryEvent` também
                // dependeria desse mesmo `save()`. O console é o único lugar que sobra — melhor
                // que desaparecer sem nenhum rastro.
                print("[NotificationReconciliationService] Falha ao salvar a reconciliação de notificações: \(error.localizedDescription)")
            }
        }
    }

    /// Tenta ler; se falhar, registra no histórico em vez de simplesmente pular aquele domínio
    /// em silêncio (o que faria os avisos daquele item ficarem desatualizados sem nenhum rastro
    /// do motivo).
    private static func attemptFetch<T>(_ label: String, context: ModelContext, _ operation: () throws -> T?) -> T? {
        do {
            return try operation()
        } catch {
            log("Não foi possível ler \(label) para reagendar os avisos correspondentes. \(error.localizedDescription)", context: context)
            return nil
        }
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
            log("Não foi possível reagendar os avisos de \(label). \(error.localizedDescription)", context: context)
        }
    }

    private static func log(_ description: String, context: ModelContext) {
        let event = HistoryEvent(eventType: .settingsChanged, eventDate: Date(), descriptionText: description)
        context.insert(event)
    }
}
