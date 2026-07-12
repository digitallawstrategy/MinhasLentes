import SwiftUI

/// Um item de `DetailStatGrid` — valor em destaque + rótulo pequeno abaixo, ex.: "12/07/2026" /
/// "Última limpeza".
struct DetailStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

/// Grade de 2 colunas para fatos secundários (datas, contagens, médias) — valor em destaque,
/// rótulo pequeno abaixo, no espírito do "Highlights" da Apple Saúde. Substitui uma pilha de
/// `StatRow` (rótulo à esquerda, valor à direita, todas as linhas com o mesmo peso), que lê como
/// planilha quando repetida várias vezes na mesma tela.
struct DetailStatGrid: View {
    let items: [DetailStatItem]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppSpacing.md, alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
            ],
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.value)
                        .font(AppTypography.subheadlineMedium)
                    Text(item.label)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    AppCard {
        DetailStatGrid(items: [
            DetailStatItem(label: "Última limpeza", value: "10/07/2026"),
            DetailStatItem(label: "Aviso antecipado", value: "17/07/2026"),
            DetailStatItem(label: "Prazo da limpeza", value: "24/07/2026"),
            DetailStatItem(label: "Intervalo configurado", value: "14 dias"),
        ])
    }
    .padding()
    .background(AppColor.surface)
}
