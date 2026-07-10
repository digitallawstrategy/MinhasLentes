import Foundation
import ActivityKit

/// Estado compartilhado da Live Activity de lentes — cobre tanto a confirmação rápida exibida
/// ao registrar um uso quanto a sessão opcional "Estou usando as lentes". Um único tipo de
/// atividade para as duas situações, distinguidas por `mode`.
///
/// Este arquivo pertence tanto ao target do app (que inicia/encerra a atividade) quanto ao da
/// extensão de widget (que desenha a UI da Live Activity e da Dynamic Island).
struct LensActivityAttributes: ActivityAttributes {
    enum Mode: String, Codable, Hashable {
        case usageConfirmation
        case wearingSession
    }

    struct ContentState: Codable, Hashable {
        var mode: Mode
        var usesRemaining: Int
        var maximumUses: Int
        /// Preenchido apenas em `.wearingSession`: quando a sessão de uso começou.
        var wearingSince: Date?
        /// Preenchido apenas em `.wearingSession`: quando o lembrete de remoção deve avisar.
        var reminderAt: Date?
    }

    /// Identificador estável do par — nunca comparar/buscar atividades pelo nome, que pode ser
    /// editado ou repetido entre pares diferentes.
    var pairID: UUID
    /// Apenas para exibição na UI da Live Activity/Dynamic Island.
    var pairName: String
}
