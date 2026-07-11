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

    /// Fundo de `AppCard`: gradiente quase imperceptível na própria superfície elevada, só para
    /// não ficar uma cor chapada — a diferença real de "elevação" vem da borda e da sombra, não
    /// do gradiente em si.
    static func cardBackground(elevated: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                AppColor.surfaceElevated,
                AppColor.surfaceElevated.opacity(elevated ? 0.94 : 0.98),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Contorno claro e fino simulando luz pegando a borda superior do cartão — só perceptível
    /// no escuro (no claro, uma borda branca sobre fundo branco não faz sentido).
    static func cardBorder(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }
}
