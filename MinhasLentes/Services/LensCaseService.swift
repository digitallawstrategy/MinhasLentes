import Foundation
import SwiftData
import WidgetKit

/// Regras de negócio do ciclo de vida do estojo físico. No máximo um `LensCase` fica `.active`
/// por vez — iniciar um novo ciclo encerra automaticamente o atual (`.replaced`), preservando o
/// histórico completo de estojos anteriores, exatamente como `LensPairService` faz com pares.
@MainActor
enum LensCaseService {

    enum ServiceError: LocalizedError {
        case persistenceFailed(String)
        case notificationSchedulingFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar o ciclo do estojo. \(detail)"
            case .notificationSchedulingFailed(let detail):
                return "O ciclo foi registrado, mas não foi possível reagendar as notificações. \(detail)"
            }
        }
    }

    static func allCases(context: ModelContext) throws -> [LensCase] {
        let descriptor = FetchDescriptor<LensCase>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func activeCase(context: ModelContext) throws -> LensCase? {
        var descriptor = FetchDescriptor<LensCase>(predicate: #Predicate { $0.statusRawValue == "active" })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    private static func save(context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            do {
                try context.save()
            } catch {
                throw ServiceError.persistenceFailed(error.localizedDescription)
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Inicia um novo ciclo de estojo. Se já houver um ciclo ativo, ele é automaticamente
    /// encerrado (`.replaced`, com `replacedAt = startDate`) — nunca fica mais de um ativo.
    @discardableResult
    static func startNewCase(
        startDate: Date,
        intervalDays: Int,
        notes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws -> LensCase {
        if let current = try activeCase(context: context) {
            current.status = .replaced
            current.replacedAt = startDate
            logEvent(
                .caseReplaced,
                date: startDate,
                descriptionText: "Estojo substituído em \(DateFormatting.short.string(from: startDate)) — ciclo iniciado em \(DateFormatting.short.string(from: current.startDate)) encerrado.",
                context: context
            )
        }

        let newCase = LensCase(startDate: startDate, intervalDays: intervalDays, notes: notes)
        context.insert(newCase)
        logEvent(
            .caseStarted,
            date: startDate,
            descriptionText: "Novo ciclo de estojo iniciado em \(DateFormatting.short.string(from: startDate)) (substituição recomendada em \(intervalDays) dias).",
            context: context
        )

        try save(context: context)

        await NotificationManager.shared.cancelLensCaseNotifications()
        do {
            try await NotificationManager.shared.scheduleLensCaseNotifications(startDate: startDate, intervalDays: intervalDays, settings: settings)
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; o ciclo permanece salvo normalmente.
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

        return newCase
    }

    /// Corrige data de início, intervalo ou observação de um ciclo já registrado, sem alterar
    /// se ele está ativo ou substituído. Reagenda as notificações se o ciclo editado for o ativo.
    static func editCase(
        _ lensCase: LensCase,
        startDate: Date,
        intervalDays: Int,
        notes: String?,
        settings: AppSettings,
        context: ModelContext
    ) async throws {
        lensCase.startDate = startDate
        lensCase.intervalDays = intervalDays
        lensCase.notes = notes
        logEvent(.caseEdited, date: Date(), descriptionText: "Ciclo de estojo iniciado em \(DateFormatting.short.string(from: startDate)) editado.", context: context)

        try save(context: context)

        guard lensCase.status == .active else { return }
        await NotificationManager.shared.cancelLensCaseNotifications()
        do {
            try await NotificationManager.shared.scheduleLensCaseNotifications(startDate: startDate, intervalDays: intervalDays, settings: settings)
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; a edição permanece salva normalmente.
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

    /// Exclui permanentemente um registro de ciclo lançado por engano. Se for o ciclo ativo,
    /// as notificações de substituição são canceladas e nenhum ciclo fica ativo até que um novo
    /// seja iniciado — o mesmo comportamento de excluir o único par de lentes existente.
    static func deleteCase(_ lensCase: LensCase, context: ModelContext) async throws {
        let wasActive = lensCase.status == .active
        let startDate = lensCase.startDate
        context.delete(lensCase)
        logEvent(.caseDeleted, date: Date(), descriptionText: "Ciclo de estojo iniciado em \(DateFormatting.short.string(from: startDate)) excluído.", context: context)
        try save(context: context)

        if wasActive {
            await NotificationManager.shared.cancelLensCaseNotifications()
        }
    }

    private static func logEvent(_ type: HistoryEventType, date: Date, descriptionText: String, context: ModelContext) {
        let event = HistoryEvent(eventType: type, eventDate: date, descriptionText: descriptionText)
        context.insert(event)
    }
}
