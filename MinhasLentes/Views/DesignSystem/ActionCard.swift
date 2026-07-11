import SwiftUI

/// Cartão com título, conteúdo livre (estatísticas, texto) e um botão de ação principal —
/// o formato repetido em quase todo cartão de registro do app (cuidado diário, limpeza
/// periódica, etc.). `detail` fica vazio (`EmptyView`) quando não há nada a mostrar além do
/// botão.
struct ActionCard<Detail: View>: View {
    let title: String
    @ViewBuilder var detail: () -> Detail
    let actionTitle: String
    var actionSystemImage: String?
    var isActionDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        AppCard {
            SectionHeader(title)
            detail()
            PrimaryActionButton(title: actionTitle, systemImage: actionSystemImage, isDisabled: isActionDisabled, action: action)
        }
    }
}

#Preview {
    ActionCard(
        title: "Cuidado diário",
        detail: {
            StatRow(label: "Último registro", value: "Nenhum registrado")
        },
        actionTitle: "Registrar cuidado diário",
        actionSystemImage: "drop.circle",
        action: {}
    )
    .padding()
}
