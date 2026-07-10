import Foundation
import Observation
import SwiftData

/// Constrói a linha do tempo unificada da tela Histórico e aplica os filtros selecionados.
@MainActor
@Observable
final class HistoryViewModel {
    var activeFilters: Set<HistoryFilter> = []
    var editingUsage: LensUsage?
    var usageToDelete: LensUsage?
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

    func buildTimeline(usages: [LensUsage], cleanings: [CaseCleaning], events: [HistoryEvent]) -> [HistoryItem] {
        var items: [HistoryItem] = []
        items.append(contentsOf: usages.map { HistoryItem(id: "usage-\($0.id)", date: $0.date, kind: .usage($0)) })
        items.append(contentsOf: cleanings.map { HistoryItem(id: "cleaning-\($0.id)", date: $0.cleaningDate, kind: .cleaning($0)) })
        items.append(contentsOf: events.map { HistoryItem(id: "event-\($0.id)", date: $0.eventDate, kind: .event($0)) })
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
}
