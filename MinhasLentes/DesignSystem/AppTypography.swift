import SwiftUI

/// Tipografia semântica sobre os estilos nativos do sistema (`Font.TextStyle`). Nenhuma fonte
/// customizada é usada neste app — todo `Font` aqui deriva de um estilo nativo, o que preserva
/// o Dynamic Type automaticamente.
enum AppTypography {
    static let largeTitle: Font = .largeTitle.weight(.bold)
    static let title: Font = .title2.weight(.semibold)
    static let headline: Font = .headline
    static let body: Font = .body
    static let subheadline: Font = .subheadline
    static let subheadlineMedium: Font = .subheadline.weight(.medium)
    static let caption: Font = .caption
    static let captionMedium: Font = .caption.weight(.medium)
    static let captionSemibold: Font = .caption.weight(.semibold)
    static let footnote: Font = .footnote
    /// Número de destaque em anéis/métricas (ex.: usos restantes). Ainda deriva de um estilo de
    /// texto nativo (`.largeTitle`, só com desenho arredondado) — nunca um tamanho fixo em
    /// pontos — para continuar acompanhando o Dynamic Type.
    static let metricValue: Font = .system(.largeTitle, design: .rounded).weight(.bold)
}
