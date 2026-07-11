import Foundation

/// Representação unificada de um evento exibido na tela de Histórico — pode ter origem em
/// um uso, uma limpeza do estojo ou um evento administrativo (início/fim de par, edição, etc).
struct HistoryItem: Identifiable {
    enum Kind {
        case usage(LensUsage)
        case cleaning(CaseCleaning)
        case routineCare(RoutineCareLog)
        case event(HistoryEvent)
    }

    let id: String
    let date: Date
    let kind: Kind

    var typeLabel: String {
        switch kind {
        case .usage: return "Uso das lentes"
        case .cleaning: return "Limpeza do estojo"
        case .routineCare: return "Cuidado diário"
        case .event(let event): return event.eventType.displayName
        }
    }

    var pairName: String? {
        switch kind {
        case .usage(let usage): return usage.lensPair?.name
        case .cleaning: return nil
        case .routineCare: return nil
        case .event(let event): return event.lensPairName
        }
    }

    var side: LensSide? {
        switch kind {
        case .usage(let usage): return usage.side
        case .cleaning: return nil
        case .routineCare: return nil
        case .event(let event): return event.side
        }
    }

    var notes: String? {
        switch kind {
        case .usage(let usage): return usage.notes
        case .cleaning(let cleaning): return cleaning.notes
        case .routineCare(let log): return log.notes
        case .event(let event): return event.descriptionText
        }
    }

    var systemImageName: String {
        switch kind {
        case .usage: return "eye"
        case .cleaning: return "sparkles"
        case .routineCare: return "drop.circle"
        case .event(let event):
            switch event.eventType {
            case .pairStarted: return "plus.circle"
            case .pairFinished: return "checkmark.seal"
            case .pairReopened: return "arrow.uturn.backward.circle"
            case .pairEdited: return "pencil.circle"
            case .pairDeleted: return "trash"
            case .pairTrashed: return "trash.circle"
            case .pairRestored: return "arrow.uturn.backward.circle"
            case .usageEdited, .cleaningEdited, .caseEdited, .routineCareEdited, .solutionEdited: return "pencil"
            case .usageDeleted, .usageUndone, .cleaningDeleted, .caseDeleted, .routineCareDeleted, .solutionDeleted: return "trash"
            case .cleaningRegistered: return "sparkles"
            case .settingsChanged: return "gearshape"
            case .usageAdded: return "eye"
            case .caseStarted: return "shippingbox"
            case .caseReplaced: return "arrow.triangle.2.circlepath"
            case .routineCareRegistered: return "drop.circle"
            case .solutionOpened: return "flask"
            case .solutionClosed: return "flask.fill"
            case .inventoryItemAdded: return "shippingbox"
            case .inventoryItemEdited: return "pencil"
            case .inventoryItemDeleted: return "trash"
            case .inventoryItemExhausted: return "tray"
            case .inventoryItemUsed: return "arrow.down.bin"
            case .professionalAdded: return "person.crop.circle.badge.plus"
            case .professionalEdited: return "person.crop.circle"
            case .professionalDeleted: return "person.crop.circle.badge.minus"
            case .appointmentScheduled: return "calendar.badge.plus"
            case .appointmentEdited: return "calendar.badge.clock"
            case .appointmentCompleted: return "calendar.badge.checkmark"
            case .appointmentCanceled: return "calendar.badge.exclamationmark"
            case .appointmentDeleted: return "calendar.badge.minus"
            case .wearSessionStarted: return "eye.circle"
            case .wearSessionEnded: return "eye.slash.circle"
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

    var underlyingRoutineCare: RoutineCareLog? {
        if case .routineCare(let log) = kind { return log }
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
    case caseLifecycle
    case routineCare
    case solutionLifecycle
    case right
    case left
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usages: return "Usos"
        case .cleanings: return "Limpezas"
        case .pairLifecycle: return "Substituições e pares"
        case .caseLifecycle: return "Ciclos do estojo"
        case .routineCare: return "Cuidado diário"
        case .solutionLifecycle: return "Solução de limpeza"
        case .right: return "Lente direita"
        case .left: return "Lente esquerda"
        case .both: return "Ambas as lentes"
        }
    }
}
