import SwiftUI

/// Cartão-base do design system: toda superfície elevada da UI deriva daqui. Substitui
/// `SectionCard` gradualmente, tela por tela — as duas convivem até a migração terminar.
struct AppCard<Content: View>: View {
    var elevated: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm, content: content)
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                elevated ? AppElevation.surfaceElevated : AppElevation.surface,
                in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
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
}
