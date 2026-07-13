import SwiftUI

/// Tom semântico compartilhado por `StatusBadge`, `ReminderCard`, `StatusCard` e `ProgressCard`
/// — a mesma ideia de "sucesso/atenção/crítico/informativo/neutro" em todo componente que
/// precisa de uma cor com significado, sem cada um inventar sua própria paleta.
///
/// `.informative` usa a cor de marca principal (indigo), não uma cor própria — a paleta oficial
/// não define uma cor de status "informativa" separada. `.neutral` usa `Color.secondary` (cinza
/// adaptativo do sistema), nunca `AppColor.secondary` (violeta): violeta é cor de marca/destaque,
/// nunca cor de status, por regra explícita da direção visual escolhida.
enum AppStatusTone {
    case success, warning, critical, informative, neutral

    var color: Color {
        switch self {
        case .success: return AppColor.success
        case .warning: return AppColor.warning
        case .critical: return AppColor.critical
        case .informative: return AppColor.primary
        case .neutral: return Color.secondary
        }
    }
}

extension LensUsageStatus {
    /// Traduz o status de utilização de um par (leitura da contagem de usos restantes) para o
    /// tom visual correspondente do design system.
    var tone: AppStatusTone {
        switch self {
        case .excellent: return .success
        case .good: return .success
        case .warning: return .warning
        case .critical: return .critical
        }
    }
}
