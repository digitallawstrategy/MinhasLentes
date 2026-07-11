import Foundation
import SwiftData

enum WearSessionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case ended

    var displayName: String {
        switch self {
        case .active: return "Em andamento"
        case .ended: return "Encerrada"
        }
    }
}

/// Uma sessão de uso ("Estou usando as lentes") — a fonte de verdade persistida do que antes só
/// existia como estado da Live Activity. Continua `.active` até o usuário dizer explicitamente
/// "Retirei as lentes", mesmo que a Live Activity desapareça, o widget reinicie, o app seja
/// fechado ou o iPhone reinicie: ao abrir de novo, a sessão ativa (se houver) é restaurada a
/// partir daqui, nunca da Live Activity (que é apenas uma apresentação derivada dela).
@Model
final class WearSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var statusRawValue: String = WearSessionStatus.active.rawValue
    var createdAt: Date = Date()

    var lensPair: LensPair?

    init(id: UUID = UUID(), startedAt: Date, lensPair: LensPair?) {
        self.id = id
        self.startedAt = startedAt
        self.statusRawValue = WearSessionStatus.active.rawValue
        self.lensPair = lensPair
        self.createdAt = Date()
    }

    var status: WearSessionStatus {
        get { WearSessionStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
}
