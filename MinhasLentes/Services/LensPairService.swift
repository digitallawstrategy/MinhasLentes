import Foundation
import SwiftData

/// Centraliza as regras de negócio de pares de lentes e usos, garantindo que o histórico
/// nunca seja apagado, que o contador nunca fique negativo e que exista no máximo um par
/// ativo por lado.
///
/// Nenhuma função aqui descarta erros de persistência silenciosamente: falhas de leitura ou
/// gravação do SwiftData são sempre propagadas como `ServiceError.persistenceFailed`, para que
/// a camada de ViewModel possa apresentá-las ao usuário.
@MainActor
enum LensPairService {

    enum ServiceError: LocalizedError, Equatable {
        case limitReached
        case duplicateUsageOnDate
        case persistenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .limitReached:
                return "O limite de utilizações deste par foi atingido. Substitua as lentes antes de registrar um novo uso."
            case .duplicateUsageOnDate:
                return "Já existe uma utilização registrada nesta data. Deseja registrar outra?"
            case .persistenceFailed(let detail):
                return "Não foi possível salvar as informações no armazenamento local. \(detail)"
            }
        }
    }

    // MARK: - Consultas

    static func activePairs(context: ModelContext) throws -> [LensPair] {
        let descriptor = FetchDescriptor<LensPair>(
            predicate: #Predicate { $0.statusRawValue == "active" },
            sortBy: [SortDescriptor(\.sequenceNumber)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func activePair(side: LensSide, context: ModelContext) throws -> LensPair? {
        try activePairs(context: context).first { $0.side == side }
    }

    static func allPairs(context: ModelContext) throws -> [LensPair] {
        let descriptor = FetchDescriptor<LensPair>(sortBy: [SortDescriptor(\.sequenceNumber, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func nextSequenceNumber(side: LensSide, context: ModelContext) throws -> Int {
        let sameSide = try allPairs(context: context).filter { $0.side == side }
        return (sameSide.first?.sequenceNumber ?? 0) + 1
    }

    static func defaultName(sequence: Int, side: LensSide) -> String {
        switch side {
        case .both: return "Par nº \(sequence)"
        case .right: return "Lente direita nº \(sequence)"
        case .left: return "Lente esquerda nº \(sequence)"
        }
    }

    private static func save(context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    // MARK: - Início e encerramento de pares

    /// Inicia um novo par/lado. Se já houver um par ativo para o mesmo lado, ele é encerrado
    /// automaticamente antes (rede de segurança para a regra "no máximo um par ativo por lado";
    /// o fluxo normal de UI já solicita confirmação e motivo antes de chegar aqui).
    @discardableResult
    static func startNewPair(
        name: String?,
        startDate: Date,
        maximumUses: Int,
        trackingMode: TrackingMode,
        side: LensSide,
        context: ModelContext
    ) throws -> LensPair {
        if let current = try activePair(side: side, context: context) {
            try finishPair(
                current,
                endDate: startDate,
                reason: current.hasReachedLimit ? .usageLimitReached : .other,
                notes: "Encerrado automaticamente ao iniciar um novo par.",
                context: context
            )
        }
        let sequence = try nextSequenceNumber(side: side, context: context)
        let resolvedName: String
        if let name, !name.isEmpty {
            resolvedName = name
        } else {
            resolvedName = defaultName(sequence: sequence, side: side)
        }
        let pair = LensPair(
            name: resolvedName,
            sequenceNumber: sequence,
            startDate: startDate,
            maximumUses: maximumUses,
            trackingMode: trackingMode,
            side: side
        )
        context.insert(pair)
        logEvent(
            .pairStarted,
            date: startDate,
            pair: pair,
            description: "\(pair.name) iniciado em \(DateFormatting.short.string(from: startDate)).",
            context: context
        )
        try save(context: context)
        return pair
    }

    static func finishPair(
        _ pair: LensPair,
        endDate: Date,
        reason: DiscardReason,
        notes: String?,
        context: ModelContext
    ) throws {
        pair.status = .finished
        pair.endDate = endDate
        pair.discardReasonValue = reason
        if let notes, !notes.isEmpty {
            pair.notes = notes
        }
        logEvent(
            .pairFinished,
            date: endDate,
            pair: pair,
            description: "\(pair.name) encerrado em \(DateFormatting.short.string(from: endDate)) — motivo: \(reason.displayName).",
            context: context
        )
        try save(context: context)
    }

    static func renamePair(_ pair: LensPair, newName: String, context: ModelContext) throws {
        guard !newName.isEmpty else { return }
        pair.name = newName
        try save(context: context)
    }

    // MARK: - Registro de usos

    @discardableResult
    static func registerUsage(
        for pair: LensPair,
        date: Date,
        side: LensSide,
        notes: String?,
        allowMultipleUsesPerDay: Bool,
        forceDuplicate: Bool,
        context: ModelContext
    ) throws -> LensUsage {
        guard !pair.hasReachedLimit else {
            throw ServiceError.limitReached
        }
        if !allowMultipleUsesPerDay && !forceDuplicate {
            let existing = pair.usages ?? []
            if LensStatisticsService.hasUsage(onSameDayAs: date, in: existing) {
                throw ServiceError.duplicateUsageOnDate
            }
        }
        let usage = LensUsage(date: date, side: side, notes: notes, lensPair: pair)
        context.insert(usage)
        logEvent(
            .usageAdded,
            date: date,
            pair: pair,
            description: "Uso registrado em \(DateFormatting.short.string(from: date)).",
            context: context
        )
        try save(context: context)
        return usage
    }

    static func deleteUsage(_ usage: LensUsage, context: ModelContext) throws {
        let pair = usage.lensPair
        let date = usage.date
        context.delete(usage)
        if let pair {
            logEvent(
                .usageDeleted,
                date: date,
                pair: pair,
                description: "Uso de \(DateFormatting.short.string(from: date)) excluído.",
                context: context
            )
        }
        try save(context: context)
    }

    static func editUsage(_ usage: LensUsage, newDate: Date, newSide: LensSide, newNotes: String?, context: ModelContext) throws {
        let oldDate = usage.date
        usage.date = newDate
        usage.side = newSide
        usage.notes = newNotes
        if let pair = usage.lensPair {
            logEvent(
                .usageEdited,
                date: newDate,
                pair: pair,
                description: "Uso alterado de \(DateFormatting.short.string(from: oldDate)) para \(DateFormatting.short.string(from: newDate)).",
                context: context
            )
        }
        try save(context: context)
    }

    @discardableResult
    static func undoLastUsage(for pair: LensPair, context: ModelContext) throws -> Bool {
        guard let last = pair.sortedUsages.first else { return false }
        let date = last.date
        context.delete(last)
        logEvent(
            .usageUndone,
            date: date,
            pair: pair,
            description: "Último uso (\(DateFormatting.short.string(from: date))) desfeito.",
            context: context
        )
        try save(context: context)
        return true
    }

    // MARK: - Auditoria

    private static func logEvent(_ type: HistoryEventType, date: Date, pair: LensPair, description: String, context: ModelContext) {
        let event = HistoryEvent(
            eventType: type,
            eventDate: date,
            lensPairID: pair.id,
            lensPairName: pair.name,
            side: pair.side,
            descriptionText: description
        )
        context.insert(event)
    }
}
