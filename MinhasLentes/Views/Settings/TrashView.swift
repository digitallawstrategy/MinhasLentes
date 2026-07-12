import SwiftUI
import SwiftData

/// Lixeira: pares movidos para cá continuam existindo, com todo o histórico de usos, e podem
/// ser restaurados como reserva a qualquer momento antes da exclusão automática.
struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensPair.sequenceNumber) private var allPairs: [LensPair]

    @State private var viewModel = TrashViewModel()

    private var trashedPairs: [LensPair] {
        allPairs
            .filter { $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            if trashedPairs.isEmpty {
                ContentUnavailableView(
                    "Lixeira vazia",
                    systemImage: "trash",
                    description: Text("Pares movidos para a lixeira ficam aqui, recuperáveis, por até \(LensPairService.trashRetentionDays) dias.")
                )
            } else {
                ForEach(trashedPairs) { pair in
                    row(for: pair)
                }
            }
        }
        .navigationTitle("Lixeira")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { viewModel.pairToPermanentlyDelete },
            set: { viewModel.pairToPermanentlyDelete = $0 }
        )) { pair in
            ConfirmDeleteByTypingSheet(
                title: "Excluir permanentemente",
                message: "Isso apaga \(pair.name) e todos os usos registrados nele para sempre. Diferente de mover para a lixeira, não pode ser desfeito."
            ) {
                viewModel.permanentlyDelete(pair, context: modelContext)
            }
        }
        .alert(
            "Não foi possível concluir a ação",
            isPresented: Binding(
                get: { viewModel.presentedError != nil },
                set: { if !$0 { viewModel.presentedError = nil } }
            ),
            presenting: viewModel.presentedError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
    }

    private func row(for pair: LensPair) -> some View {
        let daysInTrash = pair.deletedAt.map { LensStatisticsService.daysSince($0) } ?? 0
        let daysLeft = max(0, LensPairService.trashRetentionDays - daysInTrash)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pair.name)
                    .font(AppTypography.subheadlineMedium)
                Text("Excluído para sempre em \(Pluralization.count(daysLeft, "dia", "dias")), a menos que restaurado")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restaurar") {
                viewModel.restorePair(pair, context: modelContext)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button(role: .destructive) {
                viewModel.pairToPermanentlyDelete = pair
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Excluir \(pair.name) permanentemente")
        }
    }
}

#Preview {
    NavigationStack {
        TrashView()
    }
    .modelContainer(PreviewData.container)
}
