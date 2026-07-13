import SwiftUI

/// Cabeçalho de seção com título e um acessório opcional (ex.: link "Ver tudo"). Usado dentro
/// de `AppCard`/`ActionCard` no lugar de um `Text(...).font(.headline)` solto.
struct SectionHeader<Trailing: View>: View {
    let title: String
    /// Só alguns cartões têm um ícone antes do título na referência visual (ex.: "Cuidados de
    /// hoje") — a maioria não tem, então isto fica opcional em vez de virar padrão para todo
    /// `SectionHeader` existente.
    var leadingIcon: String?
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, leadingIcon: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.leadingIcon = leadingIcon
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let leadingIcon {
                Image(systemName: leadingIcon)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.primary)
                    .frame(width: 28, height: 28)
                    .background(AppColor.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                    .accessibilityHidden(true)
            }
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
