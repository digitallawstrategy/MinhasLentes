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
        case .settingsChanged: return "Alteração de configuração"
        }
    }
}
