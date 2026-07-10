import SwiftUI
import SwiftData

/// Aba Início: resumo do(s) par(es) ativo(s) e registro de uso com um toque.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensPair.sequenceNumber) private var allPairs: [LensPair]
    @Query private var allSettings: [AppSettings]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]

    @State private var viewModel = HomeViewModel()
    @State private var pairToFinish: LensPair?
    @State private var pairToEdit: LensPair?
    @State private var pairForDiary: LensPair?
    @State private var showStartNewPair = false
    @State private var startNewPairSides: [LensSide] = [.both]

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var activePairs: [LensPair] {
        allPairs.filter { $0.status == .active }
    }

    private var lastCleaning: CaseCleaning? { cleanings.first }

    private var dashboardSummary: String? {
        guard let first = activePairs.first else { return nil }
        let health = LensStatisticsService.healthStatus(
            usesRemaining: first.usesRemaining,
            maximumUses: first.maximumUses,
            goodBelowPercent: settings.healthGoodBelowPercent,
            warningBelowPercent: settings.healthWarningBelowPercent,
            criticalBelowPercent: settings.healthCriticalBelowPercent
        )
        var parts = ["\(greeting). Suas lentes estão em estado \(health.label.lowercased())."]
        parts.append("\(first.usesRemaining) utilização(ões) restantes.")
        if let lastCleaning {
            let days = Calendar.current.dateComponents([.day], from: lastCleaning.cleaningDate, to: Date()).day ?? 0
            parts.append("Estojo limpo há \(days) dia(s).")
        }
        return parts.joined(separator: " ")
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Bom dia"
        case 12..<18: return "Boa tarde"
        default: return "Boa noite"
        }
    }

    /// Lados disponíveis para iniciar um novo par. Não depende dos pares já ativos: é permitido
    /// ter mais de um par ativo simultaneamente, inclusive do mesmo lado (ex.: um par reserva).
    private var startableSides: [LensSide] {
        settings.trackingMode == .individual ? [.right, .left] : [.both]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if activePairs.isEmpty {
                        emptyState
                    } else {
                        if let dashboardSummary {
                            Text(dashboardSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if activePairs.count > 1 {
                            registerAllButton
                        }
                        ForEach(activePairs) { pair in
                            LensPairCardView(
                                pair: pair,
                                lastCleaning: lastCleaning,
                                settings: settings,
                                onRegisterUsage: { registerUsage(for: pair) },
                                onFinishPair: { pairToFinish = pair },
                                onEdit: { pairToEdit = pair },
                                onShowDiary: { pairForDiary = pair },
                                onDelete: { viewModel.deletePair(pair, context: modelContext) }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Minhas Lentes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewPairSides = startableSides
                        showStartNewPair = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Iniciar novo par")
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.showUndoToast, let message = viewModel.toastMessage {
                    ConfirmationToast(message: message, actionTitle: "Desfazer") {
                        viewModel.undoLastRegisteredUsage(context: modelContext)
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: viewModel.showUndoToast)
            .alert("Limite atingido", isPresented: $viewModel.showLimitReachedAlert) {
                Button("Entendi", role: .cancel) {}
            } message: {
                Text("O limite de utilizações deste par foi atingido. Substitua as lentes antes de registrar um novo uso.")
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
            .confirmationDialog(
                "Já existe uma utilização registrada nesta data. Deseja registrar outra?",
                isPresented: $viewModel.showDuplicateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Registrar outra utilização") {
                    viewModel.confirmDuplicateRegistration(settings: settings, context: modelContext)
                }
                Button("Cancelar", role: .cancel) {
                    viewModel.cancelDuplicateRegistration()
                }
            }
            .sheet(item: $pairToFinish) { pair in
                EndPairSheet(pair: pair) { endDate, reason, notes, startNew in
                    viewModel.finishPair(pair, endDate: endDate, reason: reason, notes: notes, context: modelContext)
                    if startNew {
                        startNewPairSides = [pair.side]
                        showStartNewPair = true
                    }
                }
            }
            .sheet(isPresented: $showStartNewPair) {
                StartNewPairSheet(defaultMaximumUses: settings.maximumUses, availableSides: startNewPairSides) { name, startDate, maximumUses, side in
                    viewModel.startNewPair(
                        name: name,
                        startDate: startDate,
                        maximumUses: maximumUses,
                        trackingMode: settings.trackingMode,
                        side: side,
                        context: modelContext
                    )
                }
            }
            .sheet(item: $pairToEdit) { pair in
                EditPairSheet(pair: pair) { name, startDate, maximumUses in
                    viewModel.editPair(pair, name: name, startDate: startDate, maximumUses: maximumUses, context: modelContext)
                }
            }
            .sheet(item: $pairForDiary) { pair in
                PairDiaryView(pair: pair, allCleanings: cleanings, warningBelowPercent: settings.healthWarningBelowPercent)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Nenhum par ativo",
                systemImage: "eye.slash",
                description: Text("Inicie um novo par de lentes para começar a registrar os usos.")
            )
            Button {
                startNewPairSides = startableSides
                showStartNewPair = true
            } label: {
                Label("Iniciar novo par", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }

    private var registerAllButton: some View {
        Button {
            registerUsageForAllActivePairs()
        } label: {
            Label("Registrar uso hoje (todos os pares)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func registerUsage(for pair: LensPair) {
        viewModel.registerUsageToday(for: pair, side: pair.side, settings: settings, context: modelContext)
    }

    private func registerUsageForAllActivePairs() {
        for pair in activePairs where !pair.hasReachedLimit {
            viewModel.registerUsageToday(for: pair, side: pair.side, settings: settings, context: modelContext)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
