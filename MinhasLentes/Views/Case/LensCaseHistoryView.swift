import SwiftUI
import SwiftData

/// Tela dedicada de gerenciamento do estojo: todos os ciclos já registrados (ativo e
/// substituídos), com edição e exclusão de lançamentos incorretos.
struct LensCaseHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensCase.startDate, order: .reverse) private var cases: [LensCase]
    @Query private var allSettings: [AppSettings]

    @State private var viewModel = LensCaseViewModel()
    @State private var caseToEdit: LensCase?
    @State private var caseToDelete: LensCase?

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    var body: some View {
        List {
            if cases.isEmpty {
                ContentUnavailableView(
                    "Nenhum ciclo registrado",
                    systemImage: "shippingbox",
                    description: Text("Inicie o primeiro ciclo do estojo em Cuidados → Estojo.")
                )
            } else {
                ForEach(cases) { lensCase in
                    row(for: lensCase)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Excluir", role: .destructive) {
                                caseToDelete = lensCase
                            }
                            Button("Editar") {
                                caseToEdit = lensCase
                            }
                            .tint(.blue)
                        }
                }
            }
        }
        .navigationTitle("Ciclos do estojo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $caseToEdit) { lensCase in
            EditLensCaseSheet(lensCase: lensCase) { startDate, intervalDays, notes in
                Task { await viewModel.editCase(lensCase, startDate: startDate, intervalDays: intervalDays, notes: notes, settings: settings, context: modelContext) }
            }
        }
        .sheet(item: $caseToDelete) { lensCase in
            ConfirmDeleteByTypingSheet(
                title: "Excluir ciclo",
                message: "Isso exclui permanentemente o ciclo do estojo iniciado em \(DateFormatting.short.string(from: lensCase.startDate)). Se for o ciclo ativo, os avisos de substituição são cancelados até que um novo ciclo seja iniciado."
            ) {
                Task { await viewModel.deleteCase(lensCase, context: modelContext) }
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

    private func row(for lensCase: LensCase) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DateFormatting.short.string(from: lensCase.startDate))
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(lensCase.status.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(lensCase.status == .active ? Color.green : Color.secondary)
            }
            if let replacedAt = lensCase.replacedAt {
                Text("Substituído em \(DateFormatting.short.string(from: replacedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Substituição recomendada em \(DateFormatting.short.string(from: lensCase.nextRecommendedReplacementDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = lensCase.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        LensCaseHistoryView()
    }
    .modelContainer(PreviewData.container)
}
