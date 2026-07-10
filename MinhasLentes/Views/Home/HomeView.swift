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
    @State private var showStartNewPair = false
    @State private var startNewPairSides: [LensSide] = [.both]

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var activePairs: [LensPair] {
        allPairs.filter { $0.status == .active }
    }

    private var lastCleaning: CaseCleaning? { cleanings.first }

    private var missingSides: [LensSide] {
        guard settings.trackingMode == .individual else {
            return activePairs.isEmpty ? [.both] : []
        }
        var sides: [LensSide] = []
        if !activePairs.contains(where: { $0.side == .right }) { sides.append(.right) }
        if !activePairs.contains(where: { $0.side == .left }) { sides.append(.left) }
        return sides
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if activePairs.isEmpty {
                        emptyState
                    } else {
                        if settings.trackingMode == .individual, activePairs.count > 1 {
                            bothSidesButton
                        }
                        ForEach(activePairs) { pair in
                            LensPairCardView(
                                pair: pair,
                                lastCleaning: lastCleaning,
                                settings: settings,
                                onRegisterUsage: { registerUsage(for: pair) },
                                onFinishPair: { pairToFinish = pair },
                                onRename: { newName in
                                    viewModel.rename(pair, to: newName, context: modelContext)
                                }
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
                if !missingSides.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            startNewPairSides = missingSides
                            showStartNewPair = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Iniciar novo par")
                    }
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
                startNewPairSides = missingSides
                showStartNewPair = true
            } label: {
                Label("Iniciar novo par", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }

    private var bothSidesButton: some View {
        Button {
            registerUsageForBothSides()
        } label: {
            Label("Registrar uso hoje (ambas as lentes)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func registerUsage(for pair: LensPair) {
        viewModel.registerUsageToday(for: pair, side: pair.side, settings: settings, context: modelContext)
    }

    private func registerUsageForBothSides() {
        for pair in activePairs where !pair.hasReachedLimit {
            viewModel.registerUsageToday(for: pair, side: pair.side, settings: settings, context: modelContext)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
