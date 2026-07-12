import SwiftUI
import SwiftData

/// Histórico de pares encerrados: quanto durou cada um, quantos usos teve de fato e por que
/// terminou — complementa o diário de um par específico com uma visão de todos os já
/// finalizados. Só leitura; editar ou excluir um par encerrado continua acontecendo pelo menu
/// do próprio card enquanto ele ainda existir (antes de ir para a lixeira).
struct LensPairHistoryView: View {
    @Query(sort: \LensPair.sequenceNumber) private var allPairs: [LensPair]

    private var finishedPairs: [LensPair] {
        allPairs
            .filter { $0.status == .finished && $0.deletedAt == nil }
            .sorted { ($0.endDate ?? $0.startDate) > ($1.endDate ?? $1.startDate) }
    }

    var body: some View {
        List {
            if finishedPairs.isEmpty {
                ContentUnavailableView(
                    "Nenhum par encerrado",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Pares encerrados aparecem aqui, com duração, usos e motivo do encerramento.")
                )
            } else {
                ForEach(finishedPairs) { pair in
                    row(for: pair)
                }
            }
        }
        .navigationTitle("Histórico de pares")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for pair: LensPair) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pair.name)
                    .font(AppTypography.subheadlineMedium)
                Spacer()
                if let reason = pair.discardReasonValue {
                    Text(reason.displayName)
                        .font(AppTypography.captionSemibold)
                        .foregroundStyle(.secondary)
                }
            }
            Text(periodText(for: pair))
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let durationDays = durationDays(for: pair) {
                    Text(Pluralization.count(durationDays, "dia", "dias"))
                }
                Text(Pluralization.count(pair.usesCount, "uso", "usos"))
                if let averageSessionDuration = averageSessionDuration(for: pair) {
                    Text("média \(DateFormatting.durationShort(averageSessionDuration))/sessão")
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(.secondary)
            if let notes = pair.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func periodText(for pair: LensPair) -> String {
        let start = DateFormatting.short.string(from: pair.startDate)
        guard let endDate = pair.endDate else { return "Desde \(start)" }
        return "\(start) – \(DateFormatting.short.string(from: endDate))"
    }

    private func durationDays(for pair: LensPair) -> Int? {
        guard let endDate = pair.endDate else { return nil }
        return LensStatisticsService.daysSince(pair.startDate, referenceDate: endDate)
    }

    private func averageSessionDuration(for pair: LensPair) -> TimeInterval? {
        LensStatisticsService.averageSessionDuration(sessions: pair.wearSessions ?? [])
    }
}

#Preview {
    NavigationStack {
        LensPairHistoryView()
    }
    .modelContainer(PreviewData.container)
}
