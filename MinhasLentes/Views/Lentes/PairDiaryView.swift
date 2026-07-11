import SwiftUI

/// "Diário das Lentes": a linha do tempo completa da vida útil de um par, do início ao fim.
struct PairDiaryView: View {
    let pair: LensPair
    let allCleanings: [CaseCleaning]
    let warningBelowPercent: Int

    private var entries: [PairDiaryEntry] {
        PairDiaryBuilder.build(pair: pair, allCleanings: allCleanings, warningBelowPercent: warningBelowPercent)
    }

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                HStack(alignment: .top, spacing: 12) {
                    Text(entry.emoji)
                        .font(.title3)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title)
                            .font(.subheadline.weight(.semibold))
                        Text(DateFormatting.short.string(from: entry.date))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let subtitle = entry.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
            .listStyle(.plain)
            .navigationTitle("Diário — \(pair.name)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let pair = LensPair(
        name: "Par nº 1",
        sequenceNumber: 1,
        startDate: Date(),
        maximumUses: 60,
        trackingMode: .pair,
        side: .both
    )
    PairDiaryView(pair: pair, allCleanings: [], warningBelowPercent: 40)
}
