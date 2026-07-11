import SwiftUI

/// Cores semânticas do design system. Os valores atuais reaproveitam cores adaptativas do
/// sistema — já corretas em modo claro, escuro e contraste aumentado sem nenhum ajuste manual —
/// como base neutra enquanto a direção visual final não é escolhida (ver issue "Documentar 3
/// propostas de direção visual"). Trocar `primary`/`secondary` para a paleta escolhida depois
/// não deve exigir mudar nenhuma View que já use estes tokens.
enum AppColor {
    /// Cor de marca principal — hoje o accent color do projeto, será substituída pela direção
    /// visual escolhida (A/B/C).
    static let primary = Color.accentColor
    /// Cor de marca secundária/destaque — neutra por enquanto.
    static let secondary = Color.indigo

    static let success = Color.green
    static let warning = Color.orange
    static let critical = Color.red
    static let informative = Color.blue

    static let surface = Color(uiColor: .systemBackground)
    static let surfaceElevated = Color(uiColor: .secondarySystemBackground)
    static let divider = Color(uiColor: .separator)
}
