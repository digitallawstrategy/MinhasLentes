import Foundation

/// Situação de um par (ou de um lado, no modo individual).
enum LensPairStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case finished
}

/// Lado ao qual um registro (par ou uso) se refere.
enum LensSide: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case both
    case right
    case left

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .both: return "Ambas"
        case .right: return "Direita"
        case .left: return "Esquerda"
        }
    }

    var shortLabel: String {
        switch self {
        case .both: return "Ambas as lentes"
        case .right: return "Lente direita"
        case .left: return "Lente esquerda"
        }
    }
}

/// Modo de controle do aplicativo: por par (uma única contagem) ou individual (direita/esquerda separados).
enum TrackingMode: String, Codable, CaseIterable, Hashable, Sendable {
    case pair
    case individual

    var displayName: String {
        switch self {
        case .pair: return "Por par"
        case .individual: return "Individual (direita/esquerda)"
        }
    }
}

/// Motivo de descarte/encerramento antecipado de um par ou lado.
enum DiscardReason: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case usageLimitReached
    case damaged
    case lost
    case discomfort
    case contaminationSuspected
    case medicalGuidance
    case storageProblem
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usageLimitReached: return "Limite de usos atingido"
        case .damaged: return "Lente danificada"
        case .lost: return "Lente perdida"
        case .discomfort: return "Desconforto"
        case .contaminationSuspected: return "Suspeita de contaminação"
        case .medicalGuidance: return "Orientação médica"
        case .storageProblem: return "Problema no armazenamento"
        case .other: return "Outro"
        }
    }
}

/// Tipo de evento administrativo registrado no histórico.
enum HistoryEventType: String, Codable, CaseIterable, Hashable, Sendable {
    case pairStarted
    case pairFinished
    case usageAdded
    case usageEdited
    case usageDeleted
    case usageUndone
    case cleaningRegistered
    case cleaningDeleted
    case cleaningEdited
    case pairReopened
    case pairEdited
    case pairDeleted
    case settingsChanged

    var displayName: String {
        switch self {
        case .pairStarted: return "Início de par"
        case .pairFinished: return "Encerramento de par"
        case .usageAdded: return "Uso registrado"
        case .usageEdited: return "Uso editado"
        case .usageDeleted: return "Uso excluído"
        case .usageUndone: return "Uso desfeito"
        case .cleaningRegistered: return "Limpeza do estojo"
        case .cleaningDeleted: return "Limpeza excluída"
        case .cleaningEdited: return "Limpeza editada"
        case .pairReopened: return "Par reaberto"
        case .pairEdited: return "Par editado"
        case .pairDeleted: return "Par excluído"
        case .settingsChanged: return "Alteração de configuração"
        }
    }
}

/// Faixa de saúde de um par, derivada dos usos restantes e das faixas configuráveis em
/// `AppSettings`. Nunca depende apenas de cor — sempre acompanhada de um rótulo textual.
enum LensHealthStatus: String, CaseIterable, Hashable, Sendable {
    case excellent
    case good
    case warning
    case critical

    var label: String {
        switch self {
        case .excellent: return "Excelente"
        case .good: return "Boa"
        case .warning: return "Próxima da troca"
        case .critical: return "Trocar imediatamente"
        }
    }

    var emoji: String {
        switch self {
        case .excellent: return "🟢"
        case .good: return "🟡"
        case .warning: return "🟠"
        case .critical: return "🔴"
        }
    }

    var symbolName: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}
