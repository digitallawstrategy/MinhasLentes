import Foundation
import SwiftData

/// Regras de negócio do ciclo de limpeza do estojo. O prazo é sempre recalculado a partir
/// da limpeza efetivamente registrada, independentemente dos usos das lentes.
@MainActor
enum CaseCleaningService {

    enum ServiceError: LocalizedError {
        case persistenceFailed(String)
        case notificationSchedulingFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar a limpeza do estojo. \(detail)"
            case .notificationSchedulingFailed(let detail):
                return "A limpeza foi registrada, mas não foi possível reagendar as notificações. \(detail)"
            }
        }
    }

    static func allCleanings(context: ModelContext) throws -> [CaseCleaning] {
        let descriptor = FetchDescriptor<CaseCleaning>(sortBy: [SortDescriptor(\.cleaningDate, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func lastCleaning(context: ModelContext) throws -> CaseCleaning? {
        try allCleanings(context: context).first
    }

    /// Registra uma nova limpeza e reagenda as notificações reais seguindo o procedimento:
    /// 1. cancela somente as notificações reais do ciclo anterior;
    /// 2. aguarda a confirmação do cancelamento junto ao sistema;
    /// 3. agenda o novo ciclo;
    /// 4. consulta as notificações pendentes para confirmar o agendamento;
    /// 5. em caso de falha no reagendamento, registra o evento no histórico e propaga o erro —
    ///    sem descartar a limpeza, que já foi salva com sucesso.
    @discardableResult
    static func registerCleaning(
        date: Date,
        notes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws -> CaseCleaning {
        let cleaning = CaseCleaning(cleaningDate: date, notes: notes)
        context.insert(cleaning)

        let event = HistoryEvent(
            eventType: .cleaningRegistered,
            eventDate: date,
            descriptionText: "Limpeza do estojo registrada em \(DateFormatting.short.string(from: date))."
        )
        context.insert(event)

        do {
            try context.save()
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }

        // 1. cancela somente as notificações reais do ciclo anterior
        // 2. cancelCaseCleaningNotifications já consulta a fila real do sistema antes de retornar,
        //    confirmando que o cancelamento foi aplicado.
        await NotificationManager.shared.cancelCaseCleaningNotifications()

        do {
            // 3. agenda o novo ciclo e 4. verifica as notificações pendentes internamente
            try await NotificationManager.shared.scheduleCaseCleaningNotifications(lastCleaningDate: date, settings: settings)
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Não é uma falha de agendamento: o usuário simplesmente ainda não autorizou
            // notificações. A tela de Configurações já orienta a ativação nos Ajustes do iPhone;
            // a limpeza permanece salva normalmente.
        } catch {
            // 5. registra a falha real de agendamento no histórico sem apagar a limpeza já salva.
            let failureEvent = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Falha ao reagendar notificações do estojo: \(error.localizedDescription)"
            )
            context.insert(failureEvent)
            // Melhor esforço: se este save específico falhar, o erro principal abaixo já será
            // propagado ao usuário de qualquer forma.
            try? context.save()
            throw ServiceError.notificationSchedulingFailed(error.localizedDescription)
        }

        return cleaning
    }

    /// Exclui uma limpeza registrada por engano e reagenda as notificações a partir da limpeza
    /// mais recente que restar (ou cancela o ciclo, se não sobrar nenhuma). Segue o mesmo
    /// procedimento de `registerCleaning`: cancela o ciclo anterior, salva a exclusão e só então
    /// tenta reagendar — uma falha no reagendamento não desfaz a exclusão, que já foi salva.
    static func deleteCleaning(
        _ cleaning: CaseCleaning,
        settings: AppSettings,
        context: ModelContext
    ) async throws {
        let date = cleaning.cleaningDate
        context.delete(cleaning)

        let event = HistoryEvent(
            eventType: .cleaningDeleted,
            eventDate: Date(),
            descriptionText: "Limpeza do estojo de \(DateFormatting.short.string(from: date)) excluída."
        )
        context.insert(event)

        do {
            try context.save()
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }

        try await rescheduleFromCurrentLast(settings: settings, context: context)
    }

    /// Corrige a data ou a observação de uma limpeza já registrada (ex.: usuário tocou em
    /// "Limpei o estojo hoje" mas quis dizer ontem). Reagenda o ciclo a partir da limpeza mais
    /// recente resultante, do mesmo modo que `registerCleaning`/`deleteCleaning`.
    static func editCleaning(
        _ cleaning: CaseCleaning,
        newDate: Date,
        newNotes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws {
        let oldDate = cleaning.cleaningDate
        cleaning.cleaningDate = newDate
        cleaning.notes = newNotes

        let event = HistoryEvent(
            eventType: .cleaningEdited,
            eventDate: Date(),
            descriptionText: "Limpeza alterada de \(DateFormatting.short.string(from: oldDate)) para \(DateFormatting.short.string(from: newDate))."
        )
        context.insert(event)

        do {
            try context.save()
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }

        try await rescheduleFromCurrentLast(settings: settings, context: context)
    }

    /// Cancela o ciclo de notificações e reagenda a partir da limpeza mais recente que restar
    /// (ou não reagenda nada, se não sobrar nenhuma). Uma falha aqui nunca desfaz a alteração
    /// que já foi salva — apenas propaga o erro para que a UI avise o usuário.
    private static func rescheduleFromCurrentLast(settings: AppSettings, context: ModelContext) async throws {
        await NotificationManager.shared.cancelCaseCleaningNotifications()

        guard let newLast = try? lastCleaning(context: context) else { return }

        do {
            try await NotificationManager.shared.scheduleCaseCleaningNotifications(lastCleaningDate: newLast.cleaningDate, settings: settings)
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; a alteração permanece salva normalmente.
        } catch {
            let failureEvent = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Falha ao reagendar notificações do estojo: \(error.localizedDescription)"
            )
            context.insert(failureEvent)
            try? context.save()
            throw ServiceError.notificationSchedulingFailed(error.localizedDescription)
        }
    }

    static func nextCleaningDate(settings: AppSettings, context: ModelContext) throws -> Date? {
        guard let last = try lastCleaning(context: context) else { return nil }
        return LensStatisticsService.nextCleaningDate(
            lastCleaningDate: last.cleaningDate,
            intervalDays: settings.cleaningIntervalDays
        )
    }

    static func advanceReminderDate(settings: AppSettings, context: ModelContext) throws -> Date? {
        guard let last = try lastCleaning(context: context) else { return nil }
        return LensStatisticsService.advanceReminderDate(
            lastCleaningDate: last.cleaningDate,
            intervalDays: settings.cleaningIntervalDays,
            advanceDays: settings.advanceReminderDays
        )
    }
}
