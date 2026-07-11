import SwiftUI

/// Cartão-base do design system: toda superfície elevada da UI deriva daqui. Substitui
/// `SectionCard` gradualmente, tela por tela — as duas convivem até a migração terminar.
///
/// O padrão usa uma cor de superfície opaca (`AppColor.surfaceElevated`), não `Material` — um
/// cartão translúcido em toda tela fica "vítreo demais" quando repetido dezenas de vezes, varia
/// de aparência conforme o que está atrás, e muda bastante com "Reduzir transparência" ativado.
/// `Material` fica reservado para `elevated: true`, quando uma superfície realmente precisa se
/// destacar sobre outros cartões (não usado em nenhuma tela hoje).
struct AppCard<Content: View>: View {
    var elevated: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm, content: content)
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if elevated {
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .fill(AppElevation.surface)
                } else {
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .fill(AppColor.surfaceElevated)
                }
            }
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
