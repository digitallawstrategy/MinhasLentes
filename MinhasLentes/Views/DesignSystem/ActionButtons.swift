import SwiftUI

@ViewBuilder
private func actionLabel(_ title: String, systemImage: String?) -> some View {
    if let systemImage {
        Label(title, systemImage: systemImage)
    } else {
        Text(title)
    }
}

/// Botão de ação principal do design system — `.borderedProminent`, largura total por padrão.
/// Usado para a ação mais importante de um cartão (registrar uso, registrar cuidado, etc.).
struct PrimaryActionButton: View {
    let title: String
    var systemImage: String?
    var isDisabled: Bool = false
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage)
                .font(AppTypography.subheadlineMedium)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled)
    }
}

/// Botão de ação secundária — `.bordered`, para a alternativa a uma ação primária (ex.:
/// "Registrar em outro dia" ao lado de "Registrar hoje").
struct SecondaryActionButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = AppColor.primary
    var isDisabled: Bool = false
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage)
                .font(AppTypography.subheadlineMedium)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .disabled(isDisabled)
    }
}

#Preview {
    VStack(spacing: AppSpacing.sm) {
        PrimaryActionButton(title: "Registrar uso hoje", systemImage: "checkmark.circle.fill") {}
        SecondaryActionButton(title: "Registrar em outro dia") {}
        PrimaryActionButton(title: "Sem ícone, sem largura total", fullWidth: false) {}
    }
    .padding()
}
