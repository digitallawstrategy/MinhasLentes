import SwiftUI

/// Cores semânticas do design system — direção visual "Indigo e violeta", modo escuro premium
/// (referência: `modelodesign.png`). Regras que este arquivo é o único lugar responsável por
/// manter:
///
/// - `primary` (indigo) e `secondary` (violeta) são cores de marca, nunca de status — nenhuma
///   View deve usar `secondary` para indicar sucesso/atenção/crítico.
/// - `success`/`warning`/`critical` são sempre verde/laranja/vermelho, nessa ordem de
///   significado, e só isso — nunca a cor de marca.
/// - Nenhum hexadecimal aparece aqui nem em nenhuma View — só os `.colorset` do asset catalog
///   guardam os valores reais, cada um com variantes de claro/escuro/contraste aumentado.
/// - `background`/`surfaceElevated` são cores de marca sutilmente tingidas (não cinza/preto
///   genérico do sistema) — no escuro, um quase-preto azulado (`#0D0D12`), não preto puro.
enum AppColor {
    /// Cor de marca principal (indigo). É o próprio accent color do projeto, então também tinge
    /// automaticamente controles nativos (tab bar, links) fora do design system.
    static let primary = Color.accentColor
    /// Cor de marca secundária/destaque (violeta) — uso pontual, nunca como cor de status.
    static let secondary = Color("AppSecondary")

    /// Verde de marca — valor fixo (não `UIColor.systemGreen`) para bater exatamente com a
    /// referência visual em modo escuro.
    static let success = Color("AppSuccess")
    static let warning = Color(uiColor: .systemOrange)
    static let critical = Color(uiColor: .systemRed)

    /// Fundo de tela — quase-preto azulado no escuro, quase-branco lavanda no claro.
    static let surface = Color("AppBackground")
    /// Fundo de cartão/superfície elevada.
    static let surfaceElevated = Color("AppSurfaceElevated")
    static let divider = Color(uiColor: .separator)
}
