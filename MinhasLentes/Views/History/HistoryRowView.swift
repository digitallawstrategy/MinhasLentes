import SwiftUI

/// Uma linha da lista de Histórico, representando um uso, uma limpeza ou um evento administrativo.
struct HistoryRowView: View {
    let item: HistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImageName)
                .font(.title3)
                .foregroundStyle(AppColor.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.typeLabel)
                    .font(AppTypography.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(DateFormatting.shortWithTime.string(from: item.date))
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                    if let side = item.side {
                        Text("• \(side.displayName)")
                            .font(AppTypography.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let pairName = item.pairName {
                    Text(pairName)
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                }
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
