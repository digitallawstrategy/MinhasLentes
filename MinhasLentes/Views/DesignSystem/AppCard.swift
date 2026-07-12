import SwiftUI

/// Só dois papéis existem hoje: o cartão comum e o cartão de maior destaque de uma tela (no
/// Início, o cartão "Em uso" — só um por tela, ou deixa de ser destaque). Nenhuma tela hoje
/// precisa de um terceiro tratamento, então um caso `.navigation` especulativo não foi criado.
enum AppCardVariant {
    case standard, featured
}

/// Cartão-base do design system: toda superfície elevada da UI deriva daqui. Substitui
/// `SectionCard` gradualmente, tela por tela — as duas convivem até a migração terminar.
///
/// Fundo em gradiente sutil (não `Material`) com uma borda fina de luz e sombra suave — o efeito
/// "elevado" da referência visual (`modelodesign.png`) vem da borda/sombra, não de transparência:
/// um cartão translúcido em toda tela fica "vítreo demais" quando repetido dezenas de vezes,
/// varia de aparência conforme o que está atrás, e muda bastante com "Reduzir transparência".
struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var variant: AppCardVariant = .standard
    @ViewBuilder var content: () -> Content

    private var isFeatured: Bool { variant == .featured }

    var body: some View {
        // `featured` não usa mais padding maior que o padrão: mais respiro perto da borda
        // ficava "pesado" num cartão que já é o primeiro da tela (revisão de aparelho real) — o
        // destaque agora vem só da borda com realce violeta e da sombra, não de ocupar mais
        // altura vertical.
        VStack(alignment: .leading, spacing: AppSpacing.sm, content: content)
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppGradient.cardBackground())
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .strokeBorder(AppGradient.cardBorder(colorScheme: colorScheme, featured: isFeatured), lineWidth: isFeatured ? 1.25 : 1)
            )
            .shadow(
                color: isFeatured ? AppColor.secondary.opacity(colorScheme == .dark ? 0.18 : 0.10) : AppShadow.floatingColor,
                radius: isFeatured ? 20 : 8,
                y: isFeatured ? 8 : 3
            )
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        AppCard {
            Text("Cartão padrão")
        }
        AppCard(variant: .featured) {
            Text("Cartão em destaque")
        }
    }
    .padding()
    .background(AppColor.surface)
}
