import SwiftUI

/// Cabeçalho de seção com título e um acessório opcional (ex.: link "Ver tudo"). Usado dentro
/// de `AppCard`/`ActionCard` no lugar de um `Text(...).font(.headline)` solto.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.headline)
            Spacer()
            trailing()
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppSpacing.md) {
        SectionHeader("Sem acessório")
        SectionHeader("Com acessório") {
            Text("Ver tudo")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
