import Foundation
import SwiftData
import WidgetKit

/// Fonte de verdade persistida da sessão de uso "Estou usando as lentes". A Live Activity
/// (`LiveActivityService`) é apenas uma apresentação derivada dela — nunca o contrário. Só um
/// `WearSession` fica `.active` por vez (um usuário só usa um conjunto de lentes de cada vez,
/// mesmo em modo individual com dois pares rastreados separadamente).
@MainActor
enum WearSessionService {

    enum ServiceError: LocalizedError {
        case persistenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar a sessão de uso. \(detail)"
            }
        }
    }

    static func allSessions(context: ModelContext) throws -> [WearSession] {
        let descriptor = FetchDescriptor<WearSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func activeSession(context: ModelContext) throws -> WearSession? {
        var descriptor = FetchDescriptor<WearSession>(predicate: #Predicate { $0.statusRawValue == "active" })
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

    /// Idempotente: se já houver uma sessão ativa, retorna ela em vez de criar outra — nunca
    /// mais de uma sessão `.active` ao mesmo tempo.
    @discardableResult
    static func startSession(for pair: LensPair, startedAt: Date, context: ModelContext) throws -> WearSession {
        if let existing = try activeSession(context: context) {
            return existing
        }
        let session = WearSession(startedAt: startedAt, lensPair: pair)
        context.insert(session)
        let event = HistoryEvent(
            eventType: .wearSessionStarted,
            eventDate: startedAt,
            lensPairID: pair.id,
            lensPairName: pair.name,
            side: pair.side,
            descriptionText: "Sessão de uso iniciada com \(pair.name) em \(DateFormatting.shortWithTime.string(from: startedAt))."
        )
        context.insert(event)
        try save(context: context)
        return session
    }

    static func endSession(_ session: WearSession, endedAt: Date, context: ModelContext) throws {
        guard session.status == .active else { return }
        session.endedAt = endedAt
        session.status = .ended
        let pairName = session.lensPair?.name ?? "par removido"
        let event = HistoryEvent(
            eventType: .wearSessionEnded,
            eventDate: endedAt,
            lensPairID: session.lensPair?.id,
            lensPairName: session.lensPair?.name,
            side: session.lensPair?.side,
            descriptionText: "Sessão de uso com \(pairName) encerrada após \(DateFormatting.durationShort(session.duration))."
        )
        context.insert(event)
        try save(context: context)
    }
}
