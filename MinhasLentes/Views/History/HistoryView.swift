import SwiftUI
import SwiftData

/// Aba Histórico: linha do tempo completa de usos, limpezas e eventos administrativos,
/// com filtros e suporte a edição/exclusão de usos.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensUsage.date, order: .reverse) private var usages: [LensUsage]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query(sort: \RoutineCareLog.date, order: .reverse) private var routineCareLogs: [RoutineCareLog]
    @Query(sort: \HistoryEvent.eventDate, order: .reverse) private var events: [HistoryEvent]
    @Query private var allSettings: [AppSettings]

    @State private var viewModel = HistoryViewModel()

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var timeline: [HistoryItem] {
        let items = viewModel.buildTimeline(usages: usages, cleanings: cleanings, routineCareLogs: routineCareLogs, events: events)
        let filtered = viewModel.applyFilters(to: items)
        return viewModel.applySearch(to: filtered)
    }

    private var sections: [HistorySection] {
        viewModel.groupedSections(from: timeline)
    }

    @ViewBuilder
    private func eventSwipeActions(for event: HistoryEvent) -> some View {
        switch event.eventType {
        case .pairStarted:
            if let pair = viewModel.pair(for: event, context: modelContext) {
                Button("Mover para a lixeira", role: .destructive) { viewModel.pairToTrash = pair }
                Button("Editar par") { viewModel.pairToEdit = pair }
                    .tint(.blue)
            }
        case .pairFinished:
            if let pair = viewModel.pair(for: event, context: modelContext), pair.status == .finished {
                Button("Mover para a lixeira", role: .destructive) { viewModel.pairToTrash = pair }
                Button("Reabrir par") { viewModel.pairToReopen = pair }
                    .tint(.green)
            }
        default:
            Button("Excluir", role: .destructive) {
                viewModel.eventToDelete = event
            }
        }
    }

    var body: some View {
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
                        ForEach(sections) { section in
                            Section(section.title) {
                                ForEach(section.items) { item in
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
                                            } else if let cleaning = item.underlyingCleaning {
                                                Button("Excluir", role: .destructive) {
                                                    viewModel.cleaningToDelete = cleaning
                                                }
                                                Button("Editar") {
                                                    viewModel.cleaningToEdit = cleaning
                                                }
                                                .tint(.blue)
                                            } else if let routineCare = item.underlyingRoutineCare {
                                                Button("Excluir", role: .destructive) {
                                                    viewModel.routineCareToDelete = routineCare
                                                }
                                                Button("Editar") {
                                                    viewModel.routineCareToEdit = routineCare
                                                }
                                                .tint(.blue)
                                            } else if let event = item.underlyingEvent {
                                                eventSwipeActions(for: event)
                                            }
                                        }
                                        .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Histórico")
            .searchable(text: $viewModel.searchText, prompt: "Buscar por tipo, par ou observação")
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
            .alert("Excluir limpeza?", isPresented: Binding(
                get: { viewModel.cleaningToDelete != nil },
                set: { if !$0 { viewModel.cleaningToDelete = nil } }
            )) {
                Button("Cancelar", role: .cancel) { viewModel.cleaningToDelete = nil }
                Button("Excluir", role: .destructive) {
                    if let cleaning = viewModel.cleaningToDelete {
                        Task { await viewModel.deleteCleaning(cleaning, settings: settings, context: modelContext) }
                    }
                    viewModel.cleaningToDelete = nil
                }
            } message: {
                Text("Os avisos de limpeza serão recalculados a partir do registro anterior, se houver.")
            }
            .sheet(item: $viewModel.cleaningToEdit) { cleaning in
                EditCleaningSheet(cleaning: cleaning) { date, notes in
                    Task { await viewModel.editCleaning(cleaning, newDate: date, newNotes: notes, settings: settings, context: modelContext) }
                }
            }
            .alert("Excluir cuidado diário?", isPresented: Binding(
                get: { viewModel.routineCareToDelete != nil },
                set: { if !$0 { viewModel.routineCareToDelete = nil } }
            )) {
                Button("Cancelar", role: .cancel) { viewModel.routineCareToDelete = nil }
                Button("Excluir", role: .destructive) {
                    if let log = viewModel.routineCareToDelete {
                        viewModel.deleteRoutineCare(log, context: modelContext)
                    }
                    viewModel.routineCareToDelete = nil
                }
            }
            .sheet(item: $viewModel.routineCareToEdit) { log in
                EditRoutineCareSheet(log: log) { date, discardedSolution, cleanedCase, airDried, notes in
                    viewModel.editRoutineCare(
                        log, newDate: date, discardedSolution: discardedSolution,
                        cleanedCase: cleanedCase, airDried: airDried, newNotes: notes, context: modelContext
                    )
                }
            }
            .sheet(item: $viewModel.pairToEdit) { pair in
                EditPairSheet(pair: pair) { name, startDate, maximumUses in
                    viewModel.editPair(pair, name: name, startDate: startDate, maximumUses: maximumUses, context: modelContext)
                }
            }
            .alert("Reabrir par?", isPresented: Binding(
                get: { viewModel.pairToReopen != nil },
                set: { if !$0 { viewModel.pairToReopen = nil } }
            )) {
                Button("Cancelar", role: .cancel) { viewModel.pairToReopen = nil }
                Button("Reabrir") {
                    if let pair = viewModel.pairToReopen {
                        viewModel.reopenPair(pair, context: modelContext)
                    }
                    viewModel.pairToReopen = nil
                }
            } message: {
                Text("O par volta a ficar ativo, com o histórico de usos preservado.")
            }
            .alert("Mover par para a lixeira?", isPresented: Binding(
                get: { viewModel.pairToTrash != nil },
                set: { if !$0 { viewModel.pairToTrash = nil } }
            )) {
                Button("Cancelar", role: .cancel) { viewModel.pairToTrash = nil }
                Button("Mover para a lixeira", role: .destructive) {
                    if let pair = viewModel.pairToTrash {
                        viewModel.moveToTrash(pair, context: modelContext)
                    }
                    viewModel.pairToTrash = nil
                }
            } message: {
                Text("Some da Home e das reservas, mas fica recuperável na Lixeira (Mais → Dados) por \(LensPairService.trashRetentionDays) dias.")
            }
            .alert("Excluir registro?", isPresented: Binding(
                get: { viewModel.eventToDelete != nil },
                set: { if !$0 { viewModel.eventToDelete = nil } }
            )) {
                Button("Cancelar", role: .cancel) { viewModel.eventToDelete = nil }
                Button("Excluir", role: .destructive) {
                    if let event = viewModel.eventToDelete {
                        viewModel.deleteEvent(event, context: modelContext)
                    }
                    viewModel.eventToDelete = nil
                }
            } message: {
                Text("Remove apenas esta entrada do histórico. Não afeta usos, limpezas ou pares.")
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

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(PreviewData.container)
}
