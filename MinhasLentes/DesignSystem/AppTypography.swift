import SwiftUI

/// Tipografia semântica sobre os estilos nativos do sistema (`Font.TextStyle`, sempre SF Pro).
/// Nenhuma fonte customizada é usada neste app — todo `Font` aqui deriva de um estilo nativo, o
/// que preserva o Dynamic Type automaticamente (suporte até tamanhos de acessibilidade XXXL).
///
/// Mapeamento para a referência visual (`modelodesign.png`, tamanhos em pt no tamanho padrão):
/// título 28 semibold, subtítulo/texto principal 15 regular, cabeçalhos de card 17 semibold,
/// texto secundário 13, números grandes 34 bold — todos batem exatamente com o tamanho padrão
/// de um `Font.TextStyle` nativo (`.title`, `.subheadline`, `.headline`, `.footnote`,
/// `.largeTitle`), então não há necessidade de tamanho fixo em nenhum caso.
enum AppTypography {
    /// Título de tela/saudação — 28pt semibold (`.title`).
    static let largeTitle: Font = .largeTitle.weight(.bold)
    static let title: Font = .title.weight(.semibold)
    /// Cabeçalho de cartão/seção — 17pt semibold (`.headline`, já semibold por padrão).
    static let headline: Font = .headline
    static let body: Font = .body
    /// Subtítulo e texto principal — 15pt regular (`.subheadline`).
    static let subheadline: Font = .subheadline
    static let subheadlineMedium: Font = .subheadline.weight(.medium)
    static let caption: Font = .caption
    static let captionMedium: Font = .caption.weight(.medium)
    static let captionSemibold: Font = .caption.weight(.semibold)
    /// Texto secundário — 13pt (`.footnote`).
    static let footnote: Font = .footnote
    /// Indicadores e badges — 11pt medium (`.caption2`, não `.caption`: a referência visual
    /// separa os dois papéis por tamanho, não só peso).
    static let badge: Font = .caption2.weight(.medium)
    /// Número de destaque em anéis/métricas (ex.: usos restantes) — 34pt bold, desenho
    /// arredondado (`.largeTitle`, nunca um tamanho fixo em pontos), para continuar acompanhando
    /// o Dynamic Type.
    static let metricValue: Font = .system(.largeTitle, design: .rounded).weight(.bold)
    /// Número de métrica compacta, 2-3 lado a lado numa faixa (`MetricStrip`) — menor que
    /// `metricValue`, que é para um único número em destaque num anel.
    static let metricCompact: Font = .system(.title2, design: .rounded).weight(.bold)
}
