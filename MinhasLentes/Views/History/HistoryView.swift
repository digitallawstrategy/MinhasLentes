import SwiftUI
import SwiftData

/// Aba Histórico: linha do tempo completa de usos, limpezas e eventos administrativos,
/// com filtros e suporte a edição/exclusão de usos.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensUsage.date, order: .reverse) private var usages: [LensUsage]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query(sort: \HistoryEvent.eventDate, order: .reverse) private var events: [HistoryEvent]
    @Query private var allSettings: [AppSettings]

    @State private var viewModel = HistoryViewModel()

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var timeline: [HistoryItem] {
        let items = viewModel.buildTimeline(usages: usages, cleanings: cleanings, events: events)
        return viewModel.applyFilters(to: items)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HistoryFilterBar(activeFilters: viewModel.activeFilters) { filter in
                    viewModel.toggleFilter(filter)
                }
                .padding(.vertical, 8)

                if timeline.isEmpty {
                    ContentUnavailableView(
                        "Nenhum evento encontrado",
                        systemImage: "clock",
                        description: Text("Ajuste os filtros ou registre um novo uso ou limpeza.")
                    )
                } else {
                    List {
                        ForEach(timeline) { item in
                            HistoryRowView(item: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if let usage = item.underlyingUsage {
                                        Button("Excluir", role: .destructive) {
                                            viewModel.usageToDelete = usage
                                        }
                                        Button("Editar") {
                                            viewModel.editingUsage = usage
                                        }
                                        .tint(.blue)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Histórico")
            .sheet(item: $viewModel.editingUsage) { usage in
                EditUsageSheet(usage: usage, allowSideSelection: settings.trackingMode == .individual) { date, side, notes in
                    viewModel.updateUsage(usage, date: date, side: side, notes: notes, context: modelContext)
                }
            }
            .alert("Excluir uso?", isPresented: Binding(
                get: { viewModel.usageToDelete != nil },
                set: { if !$0 { viewModel.usageToDelete = nil } }
            )) {
                Button("Cancelar", role: .cancel) { viewModel.usageToDelete = nil }
                Button("Excluir", role: .destructive) {
                    if let usage = viewModel.usageToDelete {
                        viewModel.deleteUsage(usage, context: modelContext)
                    }
                    viewModel.usageToDelete = nil
                }
            } message: {
                Text("Esta ação devolve uma utilização ao contador do par correspondente.")
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
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewData.container)
}
