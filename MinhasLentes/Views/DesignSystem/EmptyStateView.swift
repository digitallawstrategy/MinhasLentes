import SwiftUI

/// Estado vazio padrão do app: ícone + título + descrição, com uma ação opcional. Envolve
/// `ContentUnavailableView` para manter o comportamento de acessibilidade nativo do sistema.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    var actionTitle: String?
    var actionSystemImage: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
            if let actionTitle, let action {
                PrimaryActionButton(title: actionTitle, systemImage: actionSystemImage, fullWidth: false, action: action)
            }
        }
    }
}

#Preview {
    EmptyStateView(
        title: "Nenhum par cadastrado",
        systemImage: "eyeglasses",
        description: "Vá para a aba Lentes para iniciar seu primeiro par.",
        actionTitle: "Ir para Lentes",
        actionSystemImage: "arrow.right.circle.fill",
        action: {}
    )
    .padding()
}
