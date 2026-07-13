import SwiftUI

@ViewBuilder
private func actionLabel(_ title: String, systemImage: String?) -> some View {
    if let systemImage {
        Label(title, systemImage: systemImage)
    } else {
        Text(title)
    }
}

/// Botão de ação principal do design system: cápsula em gradiente indigo → violeta, altura
/// mínima estável — não usa `.borderedProminent`, que renderiza como um botão SwiftUI padrão e
/// não a "cápsula com gradiente" pedida pela referência visual. Usado para a ação mais
/// importante de um cartão (registrar uso, registrar cuidado, etc.).
struct PrimaryActionButton: View {
    let title: String
    var systemImage: String?
    var isDisabled: Bool = false
    var fullWidth: Bool = true
    /// Linha de ação compacta dividindo espaço com outra (ex.: dentro do cartão "Em uso") —
    /// substitui o antigo `.controlSize(.small)`, que não tem efeito nenhum fora de um
    /// `ButtonStyle` nativo.
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage)
                .font(AppTypography.subheadlineMedium)
                .lineLimit(1)
                // 0.6, não 0.8: confirmado no simulador que 0.8 ainda truncava com "…" em
                // Dynamic Type "Accessibility Large" com títulos mais longos como "Registrar
                // cuidado diário". Isto é rótulo de ação de verdade (não decorativo) — encolhe
                // em vez de esconder texto, mas não mais do que o necessário pra caber.
                .minimumScaleFactor(0.6)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(minHeight: compact ? 40 : 52)
                .padding(.horizontal, AppSpacing.md)
                .foregroundStyle(.white)
        }
        .background(AppGradient.primaryButtonBackground, in: Capsule())
        .opacity(isDisabled ? 0.4 : 1)
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .pressScale()
    }
}

/// Botão de ação secundária: cápsula com fundo escuro translúcido e borda violeta discreta —
/// para a alternativa a uma ação primária (ex.: "Registrar em outro dia" ao lado de "Registrar
/// hoje"). Nunca preenchido: a hierarquia visual em relação ao primário vem exatamente de não
/// ter o gradiente sólido.
struct SecondaryActionButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = AppColor.primary
    var isDisabled: Bool = false
    var fullWidth: Bool = true
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage)
                .font(AppTypography.subheadlineMedium)
                .lineLimit(1)
                // 0.6, não 0.8: confirmado no simulador que 0.8 ainda truncava com "…" em
                // Dynamic Type "Accessibility Large" com títulos mais longos como "Registrar
                // cuidado diário". Isto é rótulo de ação de verdade (não decorativo) — encolhe
                // em vez de esconder texto, mas não mais do que o necessário pra caber.
                .minimumScaleFactor(0.6)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(minHeight: compact ? 40 : 52)
                .padding(.horizontal, AppSpacing.md)
                .foregroundStyle(tint)
        }
        .background(AppColor.surfaceElevated.opacity(0.7), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1.25))
        .opacity(isDisabled ? 0.4 : 1)
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .pressScale()
    }
}

#Preview {
    VStack(spacing: AppSpacing.sm) {
        PrimaryActionButton(title: "Registrar uso hoje", systemImage: "checkmark.circle.fill") {}
        SecondaryActionButton(title: "Registrar em outro dia") {}
        PrimaryActionButton(title: "Sem ícone, sem largura total", fullWidth: false) {}
        HStack {
            PrimaryActionButton(title: "Compacto", compact: true) {}
            SecondaryActionButton(title: "Compacto", compact: true) {}
        }
    }
    .padding()
    .background(AppColor.surface)
}
