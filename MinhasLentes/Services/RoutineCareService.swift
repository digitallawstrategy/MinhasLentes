import Foundation
import SwiftData
import WidgetKit

/// Regras de negócio do cuidado rotineiro pós-remoção (descartar solução, limpar o estojo,
/// deixar secar ao ar livre). Ao contrário da limpeza periódica, não tem prazo nem notificações
/// — é apenas um registro de hábito no histórico.
@MainActor
enum RoutineCareService {

    enum ServiceError: LocalizedError {
        case persistenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar o registro de cuidado diário. \(detail)"
            }
        }
    }

    static func allLogs(context: ModelContext) throws -> [RoutineCareLog] {
        let descriptor = FetchDescriptor<RoutineCareLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func lastLog(context: ModelContext) throws -> RoutineCareLog? {
        try allLogs(context: context).first
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

    @discardableResult
    static func registerCare(
        date: Date,
        discardedSolution: Bool,
        cleanedCase: Bool,
        airDried: Bool,
        notes: String?,
        context: ModelContext
    ) throws -> RoutineCareLog {
        let log = RoutineCareLog(date: date, discardedSolution: discardedSolution, cleanedCase: cleanedCase, airDried: airDried, notes: notes)
        context.insert(log)
        let event = HistoryEvent(
            eventType: .routineCareRegistered,
            eventDate: date,
            descriptionText: "Cuidado diário registrado em \(DateFormatting.short.string(from: date))."
        )
        context.insert(event)
        try save(context: context)
        return log
    }

    static func deleteCare(_ log: RoutineCareLog, context: ModelContext) throws {
        let date = log.date
        context.delete(log)
        let event = HistoryEvent(
            eventType: .routineCareDeleted,
            eventDate: Date(),
            descriptionText: "Cuidado diário de \(DateFormatting.short.string(from: date)) excluído."
        )
        context.insert(event)
        try save(context: context)
    }

    static func editCare(
        _ log: RoutineCareLog,
        newDate: Date,
        discardedSolution: Bool,
        cleanedCase: Bool,
        airDried: Bool,
        newNotes: String?,
        context: ModelContext
    ) throws {
        let oldDate = log.date
        log.date = newDate
        log.discardedSolution = discardedSolution
        log.cleanedCase = cleanedCase
        log.airDried = airDried
        log.notes = newNotes
        let event = HistoryEvent(
            eventType: .routineCareEdited,
            eventDate: newDate,
            descriptionText: "Cuidado diário alterado de \(DateFormatting.short.string(from: oldDate)) para \(DateFormatting.short.string(from: newDate))."
        )
        context.insert(event)
        try save(context: context)
    }
}
