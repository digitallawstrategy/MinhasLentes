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
        .alert(
            "Excluir \(viewModel.pairToPermanentlyDelete?.name ?? "par") permanentemente?",
            isPresented: Binding(
                get: { viewModel.pairToPermanentlyDelete != nil },
                set: { if !$0 { viewModel.pairToPermanentlyDelete = nil } }
            )
        ) {
            Button("Cancelar", role: .cancel) { viewModel.pairToPermanentlyDelete = nil }
            Button("Excluir para sempre", role: .destructive) {
                if let pair = viewModel.pairToPermanentlyDelete {
                    viewModel.permanentlyDelete(pair, context: modelContext)
                }
                viewModel.pairToPermanentlyDelete = nil
            }
        } message: {
            Text("Apaga o par e todos os usos registrados nele para sempre. Diferente de mover para a lixeira, não pode ser desfeito.")
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
                    .font(.subheadline.weight(.medium))
                Text("Excluído para sempre em \(daysLeft) dia(s), a menos que restaurado")
                    .font(.caption)
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
