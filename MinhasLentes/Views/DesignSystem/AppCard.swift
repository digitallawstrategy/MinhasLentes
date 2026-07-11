import SwiftUI

/// Cartão-base do design system: toda superfície elevada da UI deriva daqui. Substitui
/// `SectionCard` gradualmente, tela por tela — as duas convivem até a migração terminar.
///
/// Fundo em gradiente sutil (não `Material`) com uma borda fina de luz e sombra suave — o efeito
/// "elevado" da referência visual (`modelodesign.png`) vem da borda/sombra, não de transparência:
/// um cartão translúcido em toda tela fica "vítreo demais" quando repetido dezenas de vezes,
/// varia de aparência conforme o que está atrás, e muda bastante com "Reduzir transparência".
struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var elevated: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm, content: content)
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppGradient.cardBackground(elevated: elevated))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .strokeBorder(AppGradient.cardBorder(colorScheme: colorScheme), lineWidth: 1)
            )
            .shadow(
                color: AppShadow.floatingColor,
                radius: elevated ? 16 : 8,
                y: elevated ? 6 : 3
            )
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        AppCard {
            Text("Cartão padrão")
        }
        AppCard(elevated: true) {
            Text("Cartão elevado")
        }
    }
    .padding()
    .background(AppColor.surface)
}
