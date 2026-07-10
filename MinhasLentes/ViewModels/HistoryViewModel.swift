import Foundation
import Observation
import SwiftData

/// Constrói a linha do tempo unificada da tela Histórico e aplica os filtros selecionados.
@MainActor
@Observable
final class HistoryViewModel {
    var activeFilters: Set<HistoryFilter> = []
    var searchText: String = ""
    var editingUsage: LensUsage?
    var usageToDelete: LensUsage?
    var cleaningToDelete: CaseCleaning?
    var cleaningToEdit: CaseCleaning?
    var pairToEdit: LensPair?
    var pairToReopen: LensPair?
    var pairToTrash: LensPair?
    var eventToDelete: HistoryEvent?
    var presentedError: IdentifiableError?

    func toggleFilter(_ filter: HistoryFilter) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            activeFilters.insert(filter)
        }
    }

    func clearFilters() {
        activeFilters.removeAll()
    }

    /// Tipos de evento que duplicariam um registro já visível na linha do tempo — `usageAdded`
    /// e `cleaningRegistered`/`cleaningEdited` descrevem exatamente o que o `LensUsage`/
    /// `CaseCleaning` correspondente já mostra por si só. `usageDeleted`/`usageUndone`/
    /// `cleaningDeleted` continuam visíveis: depois de excluído, o evento é o único registro
    /// que sobra de que aquilo existiu.
    private static let eventTypesHiddenFromTimeline: Set<HistoryEventType> = [
        .usageAdded, .usageEdited, .cleaningRegistered, .cleaningEdited,
    ]

    func buildTimeline(usages: [LensUsage], cleanings: [CaseCleaning], events: [HistoryEvent]) -> [HistoryItem] {
        var items: [HistoryItem] = []
        items.append(contentsOf: usages.map { HistoryItem(id: "usage-\($0.id)", date: $0.date, kind: .usage($0)) })
        items.append(contentsOf: cleanings.map { HistoryItem(id: "cleaning-\($0.id)", date: $0.cleaningDate, kind: .cleaning($0)) })
        items.append(contentsOf: events
            .filter { !Self.eventTypesHiddenFromTimeline.contains($0.eventType) }
            .map { HistoryItem(id: "event-\($0.id)", date: $0.eventDate, kind: .event($0)) }
        )
        return items.sorted { $0.date > $1.date }
    }

    func applyFilters(to items: [HistoryItem]) -> [HistoryItem] {
        guard !activeFilters.isEmpty else { return items }
        return items.filter { item in
            activeFilters.contains { filter in
                matches(item: item, filter: filter)
            }
        }
    }

    func applySearch(to items: [HistoryItem]) -> [HistoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.typeLabel.localizedCaseInsensitiveContains(query)
            || (item.pairName?.localizedCaseInsensitiveContains(query) ?? false)
            || (item.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func groupedSections(from items: [HistoryItem]) -> [HistorySection] {
        HistoryGrouping.group(items)
    }

    private func matches(item: HistoryItem, filter: HistoryFilter) -> Bool {
        switch filter {
        case .usages:
            if case .usage = item.kind { return true }
            return false
        case .cleanings:
            if case .cleaning = item.kind { return true }
            return false
        case .pairLifecycle:
            if case .event(let event) = item.kind {
                return event.eventType == .pairStarted || event.eventType == .pairFinished
            }
            return false
        case .right:
            return item.side == .right
        case .left:
            return item.side == .left
        case .both:
            return item.side == .both
        }
    }

    func deleteUsage(_ usage: LensUsage, context: ModelContext) {
        do {
            try LensPairService.deleteUsage(usage, context: context)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível excluir o uso. \(error.localizedDescription)")
        }
    }

    func updateUsage(_ usage: LensUsage, date: Date, side: LensSide, notes: String?, context: ModelContext) {
        do {
            try LensPairService.editUsage(usage, newDate: date, newSide: side, newNotes: notes, context: context)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar a edição do uso. \(error.localizedDescription)")
        }
    }

    func deleteCleaning(_ cleaning: CaseCleaning, settings: AppSettings, context: ModelContext) async {
        do {
            try await CaseCleaningService.deleteCleaning(cleaning, settings: settings, context: context)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível excluir a limpeza. \(error.localizedDescription)")
        }
    }

    func editCleaning(_ cleaning: CaseCleaning, newDate: Date, newNotes: String?, settings: AppSettings, context: ModelContext) async {
        do {
            try await CaseCleaningService.editCleaning(cleaning, newDate: newDate, newNotes: newNotes, settings: settings, context: context)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar a edição da limpeza. \(error.localizedDescription)")
        }
    }

    /// Resolve o par referenciado por um evento administrativo (início/encerramento de par),
    /// já que `HistoryEvent` guarda apenas o identificador — de propósito, para o histórico
    /// continuar legível mesmo que o par seja editado ou excluído depois.
    func pair(for event: HistoryEvent, context: ModelContext) -> LensPair? {
        guard let id = event.lensPairID else { return nil }
        return try? LensPairService.pair(withID: id, context: context)
    }

    func editPair(_ pair: LensPair, name: String, startDate: Date, maximumUses: Int, context: ModelContext) {
        do {
            try LensPairService.editPair(pair, name: name, startDate: startDate, maximumUses: maximumUses, context: context)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar as alterações do par. \(error.localizedDescription)")
        }
    }

    func reopenPair(_ pair: LensPair, context: ModelContext) {
        do {
            try LensPairService.reopenPair(pair, context: context)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível reabrir o par. \(error.localizedDescription)")
        }
    }

    func moveToTrash(_ pair: LensPair, context: ModelContext) {
        do {
            try LensPairService.moveToTrash(pair, context: context)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível mover o par para a lixeira. \(error.localizedDescription)")
        }
    }

    /// Remove um registro administrativo avulso do histórico (ex.: duplicado), sem qualquer
    /// efeito sobre usos, limpezas ou pares — esses são corrigidos nos próprios registros.
    func deleteEvent(_ event: HistoryEvent, context: ModelContext) {
        context.delete(event)
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível excluir o registro. \(error.localizedDescription)")
        }
    }
}
