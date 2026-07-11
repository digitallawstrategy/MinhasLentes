import SwiftUI

/// Tom semântico compartilhado por `StatusBadge`, `ReminderCard`, `StatusCard` e `ProgressCard`
/// — a mesma ideia de "sucesso/atenção/crítico/informativo/neutro" em todo componente que
/// precisa de uma cor com significado, sem cada um inventar sua própria paleta.
enum AppStatusTone {
    case success, warning, critical, informative, neutral

    var color: Color {
        switch self {
        case .success: return AppColor.success
        case .warning: return AppColor.warning
        case .critical: return AppColor.critical
        case .informative: return AppColor.informative
        case .neutral: return AppColor.secondary
        }
    }
}
