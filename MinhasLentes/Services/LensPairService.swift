import Foundation
import SwiftData

/// Centraliza as regras de negócio de pares de lentes e usos, garantindo que o histórico
/// nunca seja apagado e que o contador nunca fique negativo.
///
/// No máximo um par por lado pode estar `.inUse` — é esse que acumula usos e aparece na tela
/// Início. Quantos pares `.reserve` existirem por lado, guardados para depois, não há limite.
/// Trocar qual par está em uso é sempre uma decisão explícita do usuário (`promoteToInUse`,
/// ou automaticamente ao iniciar um novo par "para usar agora"), nunca implícita.
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

    static func inUsePairs(context: ModelContext) throws -> [LensPair] {
        let descriptor = FetchDescriptor<LensPair>(
            predicate: #Predicate { $0.statusRawValue == "inUse" },
            sortBy: [SortDescriptor(\.sequenceNumber)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func reservePairs(context: ModelContext) throws -> [LensPair] {
        let descriptor = FetchDescriptor<LensPair>(
            predicate: #Predicate { $0.statusRawValue == "reserve" },
            sortBy: [SortDescriptor(\.sequenceNumber)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func allPairs(context: ModelContext) throws -> [LensPair] {
        let descriptor = FetchDescriptor<LensPair>(sortBy: [SortDescriptor(\.sequenceNumber, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func pair(withID id: UUID, context: ModelContext) throws -> LensPair? {
        var descriptor = FetchDescriptor<LensPair>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
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

    /// Inicia um novo par/lado. Por padrão (`asReserve: false`) o novo par passa a estar
    /// `.inUse` e, se já houver outro par em uso no mesmo lado, ele é rebaixado para
    /// `.reserve` — nunca encerrado automaticamente, permanece disponível e correto no
    /// histórico. Com `asReserve: true`, o par entra direto como reserva, sem mexer no que já
    /// está em uso.
    @discardableResult
    static func startNewPair(
        name: String?,
        startDate: Date,
        maximumUses: Int,
        trackingMode: TrackingMode,
        side: LensSide,
        asReserve: Bool = false,
        context: ModelContext
    ) throws -> LensPair {
        let sequence = try nextSequenceNumber(side: side, context: context)
        let resolvedName: String
        if let name, !name.isEmpty {
            resolvedName = name
        } else {
            resolvedName = defaultName(sequence: sequence, side: side)
        }

        let previousInUse = asReserve ? nil : try inUsePairs(context: context).first { $0.side == side }

        let pair = LensPair(
            name: resolvedName,
            sequenceNumber: sequence,
            startDate: startDate,
            maximumUses: maximumUses,
            trackingMode: trackingMode,
            side: side
        )
        pair.status = asReserve ? .reserve : .inUse
        context.insert(pair)

        if let previousInUse {
            previousInUse.status = .reserve
            logEvent(
                .pairEdited,
                date: startDate,
                pair: previousInUse,
                description: "\(previousInUse.name) movido para reserva ao iniciar \(pair.name).",
                context: context
            )
        }

        logEvent(
            .pairStarted,
            date: startDate,
            pair: pair,
            description: "\(pair.name) iniciado em \(DateFormatting.short.string(from: startDate)) (\(pair.status.displayName)).",
            context: context
        )
        try save(context: context)
        return pair
    }

    /// Promove um par reserva a "em uso", rebaixando o par que estava em uso no mesmo lado
    /// (se houver) para reserva. Não afeta o histórico de usos de nenhum dos dois.
    static func promoteToInUse(_ pair: LensPair, context: ModelContext) throws {
        guard pair.status == .reserve else { return }
        if let current = try inUsePairs(context: context).first(where: { $0.side == pair.side && $0.id != pair.id }) {
            current.status = .reserve
            logEvent(
                .pairEdited,
                date: Date(),
                pair: current,
                description: "\(current.name) movido para reserva ao ativar \(pair.name).",
                context: context
            )
        }
        pair.status = .inUse
        logEvent(.pairEdited, date: Date(), pair: pair, description: "\(pair.name) passou a estar em uso.", context: context)
        try save(context: context)
    }

    /// Move um par em uso para reserva sem promover nenhum outro em seu lugar — o lado fica
    /// temporariamente sem par em uso, até o usuário promover uma reserva ou iniciar outro.
    static func demoteToReserve(_ pair: LensPair, context: ModelContext) throws {
        guard pair.status == .inUse else { return }
        pair.status = .reserve
        logEvent(.pairEdited, date: Date(), pair: pair, description: "\(pair.name) movido para reserva.", context: context)
        try save(context: context)
    }

    /// Corrige, em qualquer inconsistência residual (ex.: dados de uma versão anterior ao
    /// conceito de reserva), a regra de "no máximo um par em uso por lado": mantém o par mais
    /// antigo em uso e rebaixa os demais para reserva. Idempotente — seguro chamar toda vez
    /// que o app abre.
    static func normalizeInUseInvariant(context: ModelContext) throws {
        let candidates = try inUsePairs(context: context)
        let bySide = Dictionary(grouping: candidates, by: { $0.side })
        var changed = false
        for (_, group) in bySide where group.count > 1 {
            let sorted = group.sorted { $0.startDate < $1.startDate }
            for extra in sorted.dropFirst() {
                extra.status = .reserve
                changed = true
            }
        }
        guard changed else { return }
        try save(context: context)
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

    /// Corrige identificação, data de início e limite de usos de um par — inclusive um par já
    /// encerrado, para acertar um dado lançado errado sem precisar reabri-lo.
    static func editPair(
        _ pair: LensPair,
        name: String,
        startDate: Date,
        maximumUses: Int,
        context: ModelContext
    ) throws {
        pair.name = name.isEmpty ? pair.name : name
        pair.startDate = startDate
        pair.maximumUses = maximumUses
        logEvent(
            .pairEdited,
            date: Date(),
            pair: pair,
            description: "\(pair.name) editado.",
            context: context
        )
        try save(context: context)
    }

    /// Desfaz um encerramento feito por engano: o par volta como reserva (nunca substitui
    /// automaticamente o que já estiver em uso no mesmo lado), sem apagar o histórico de usos
    /// que ele já tinha. Para voltar a usá-lo de fato, promova com `promoteToInUse`.
    static func reopenPair(_ pair: LensPair, context: ModelContext) throws {
        pair.status = .reserve
        pair.endDate = nil
        pair.discardReason = nil
        logEvent(
            .pairReopened,
            date: Date(),
            pair: pair,
            description: "\(pair.name) reaberto como reserva.",
            context: context
        )
        try save(context: context)
    }

    /// Exclui permanentemente um par criado por engano, junto com os usos registrados nele.
    /// Ao contrário das demais correções deste serviço, esta ação não pode ser desfeita — por
    /// isso a UI deve sempre confirmar antes de chamar esta função.
    static func deletePair(_ pair: LensPair, context: ModelContext) throws {
        let name = pair.name
        let deletedUsesCount = pair.usesCount
        for usage in pair.usages ?? [] {
            context.delete(usage)
        }
        let event = HistoryEvent(
            eventType: .pairDeleted,
            eventDate: Date(),
            lensPairID: pair.id,
            lensPairName: name,
            side: pair.side,
            descriptionText: "\(name) excluído permanentemente, junto com \(deletedUsesCount) uso(s)."
        )
        context.insert(event)
        context.delete(pair)
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
