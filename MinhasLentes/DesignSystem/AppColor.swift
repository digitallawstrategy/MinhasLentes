import SwiftUI

/// Cores semânticas do design system — direção visual oficial "Indigo e violeta" (issue #10,
/// decidida). Regras que este arquivo é o único lugar responsável por manter:
///
/// - `primary` (indigo) e `secondary` (violeta) são cores de marca, nunca de status — nenhuma
///   View deve usar `secondary` para indicar sucesso/atenção/crítico.
/// - `success`/`warning`/`critical` são sempre verde/laranja/vermelho, nessa ordem de
///   significado, e só isso — nunca a cor de marca.
/// - `primary`/`secondary` vêm do asset catalog (`AccentColor`/`AppSecondary`, com variantes de
///   claro/escuro/contraste aumentado já definidas ali); nenhum hexadecimal aparece aqui nem em
///   nenhuma View — só os dois arquivos de asset guardam os valores reais.
enum AppColor {
    /// Cor de marca principal (indigo). É o próprio accent color do projeto, então também tinge
    /// automaticamente controles nativos (tab bar, links) fora do design system.
    static let primary = Color.accentColor
    /// Cor de marca secundária/destaque (violeta) — uso pontual, nunca como cor de status.
    static let secondary = Color("AppSecondary")

    /// Cores do sistema (`UIColor.systemGreen`/`.systemOrange`/`.systemRed`), não valores de
    /// marca: já vêm com variantes de contraste aumentado do próprio UIKit, sem precisar de
    /// asset customizado.
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let critical = Color(uiColor: .systemRed)

    static let surface = Color(uiColor: .systemBackground)
    static let surfaceElevated = Color(uiColor: .secondarySystemBackground)
    static let divider = Color(uiColor: .separator)
}
