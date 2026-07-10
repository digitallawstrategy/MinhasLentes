import Foundation

/// Representação unificada de um evento exibido na tela de Histórico — pode ter origem em
/// um uso, uma limpeza do estojo ou um evento administrativo (início/fim de par, edição, etc).
struct HistoryItem: Identifiable {
    enum Kind {
        case usage(LensUsage)
        case cleaning(CaseCleaning)
        case event(HistoryEvent)
    }

    let id: String
    let date: Date
    let kind: Kind

    var typeLabel: String {
        switch kind {
        case .usage: return "Uso das lentes"
        case .cleaning: return "Limpeza do estojo"
        case .event(let event): return event.eventType.displayName
        }
    }

    var pairName: String? {
        switch kind {
        case .usage(let usage): return usage.lensPair?.name
        case .cleaning: return nil
        case .event(let event): return event.lensPairName
        }
    }

    var side: LensSide? {
        switch kind {
        case .usage(let usage): return usage.side
        case .cleaning: return nil
        case .event(let event): return event.side
        }
    }

    var notes: String? {
        switch kind {
        case .usage(let usage): return usage.notes
        case .cleaning(let cleaning): return cleaning.notes
        case .event(let event): return event.descriptionText
        }
    }

    var systemImageName: String {
        switch kind {
        case .usage: return "eye"
        case .cleaning: return "sparkles"
        case .event(let event):
            switch event.eventType {
            case .pairStarted: return "plus.circle"
            case .pairFinished: return "checkmark.seal"
            case .pairReopened: return "arrow.uturn.backward.circle"
            case .pairEdited: return "pencil.circle"
            case .pairDeleted: return "trash"
            case .pairTrashed: return "trash.circle"
            case .pairRestored: return "arrow.uturn.backward.circle"
            case .usageEdited, .cleaningEdited: return "pencil"
            case .usageDeleted, .usageUndone, .cleaningDeleted: return "trash"
            case .cleaningRegistered: return "sparkles"
            case .settingsChanged: return "gearshape"
            case .usageAdded: return "eye"
            }
        }
    }

    var underlyingUsage: LensUsage? {
        if case .usage(let usage) = kind { return usage }
        return nil
    }

    var underlyingCleaning: CaseCleaning? {
        if case .cleaning(let cleaning) = kind { return cleaning }
        return nil
    }

    var underlyingEvent: HistoryEvent? {
        if case .event(let event) = kind { return event }
        return nil
    }
}

/// Filtros disponíveis na tela de Histórico. Nenhum filtro selecionado equivale a "mostrar tudo".
enum HistoryFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case usages
    case cleanings
    case pairLifecycle
    case right
    case left
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usages: return "Usos"
        case .cleanings: return "Limpezas"
        case .pairLifecycle: return "Substituições e pares"
        case .right: return "Lente direita"
        case .left: return "Lente esquerda"
        case .both: return "Ambas as lentes"
        }
    }
}
