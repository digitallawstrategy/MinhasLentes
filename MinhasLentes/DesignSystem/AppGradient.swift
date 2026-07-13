import SwiftUI

/// Gradientes do design system — sempre sutis (referência: `modelodesign.png`, "fundo com
/// gradiente sutil indigo → violeta", "card com gradiente escuro elevado e borda suave"). Nunca
/// um gradiente saturado/chamativo: a marca aparece na ambientação, não grita.
enum AppGradient {
    /// Fundo ambiente de tela: um gradiente diagonal muito sutil de indigo para violeta sobre a
    /// cor de fundo — visível o suficiente para dar profundidade, nunca a ponto de brigar com o
    /// conteúdo ou prejudicar a leitura do texto por cima.
    static func ambientBackground(colorScheme: ColorScheme) -> LinearGradient {
        let opacity = colorScheme == .dark ? 0.16 : 0.05
        return LinearGradient(
            colors: [
                AppColor.primary.opacity(opacity),
                AppColor.surface,
                AppColor.secondary.opacity(opacity * 0.7),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Fundo de `AppCard`: gradiente vertical entre `surfaceElevated` e `surfaceElevatedEnd` —
    /// dois pontos de cor de verdade (não uma opacidade sobre a mesma cor), para bater com a
    /// referência visual (`#1C1C23 → #14141A` no escuro), mas sempre sutil o bastante para nunca
    /// brigar com o conteúdo por cima.
    static func cardBackground() -> LinearGradient {
        LinearGradient(
            colors: [AppColor.surfaceElevated, AppColor.surfaceElevatedEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Contorno claro e fino simulando luz pegando a borda superior do cartão — só perceptível
    /// no escuro (no claro, uma borda branca sobre fundo branco não faz sentido). `featured`
    /// mistura um toque de violeta ao branco/preto de base, reservado para o cartão de maior
    /// destaque da tela (nunca todo cartão, ou deixa de ser destaque).
    static func cardBorder(colorScheme: ColorScheme, featured: Bool = false) -> Color {
        let base = colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
        guard featured else { return base }
        return AppColor.secondary.opacity(colorScheme == .dark ? 0.35 : 0.22)
    }

    /// Preenchimento dos botões primários — cápsula em gradiente indigo → violeta, sempre a
    /// mesma dupla de cores da marca, nunca outra combinação por tela.
    static let primaryButtonBackground = LinearGradient(
        colors: [AppColor.primary, AppColor.secondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Fundo do selo de sucesso (ex.: "Uso registrado hoje") — verde translúcido com um
    /// gradiente quase imperceptível, em vez de uma única opacidade chapada.
    static let successPillBackground = LinearGradient(
        colors: [AppColor.success.opacity(0.22), AppColor.success.opacity(0.14)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Fundo da barra de abas — superfície elevada com um leve gradiente vertical, para o caso
    /// nativo (`.toolbarBackground`) continuar visualmente da mesma família dos cartões.
    static func floatingBarBackground(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? AppColor.surfaceElevated.opacity(0.96) : AppColor.surfaceElevated
    }
}
