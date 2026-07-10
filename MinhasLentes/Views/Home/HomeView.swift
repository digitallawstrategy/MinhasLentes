import SwiftUI
import SwiftData

/// Aba Início: resumo do(s) par(es) em uso, reservas disponíveis e registro de uso com um toque.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensPair.sequenceNumber) private var allPairs: [LensPair]
    @Query private var allSettings: [AppSettings]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]

    @State private var viewModel = HomeViewModel()
    @State private var pairToFinish: LensPair?
    @State private var pairToEdit: LensPair?
    @State private var pairForDiary: LensPair?
    @State private var pairToDelete: LensPair?
    @State private var showStartNewPair = false
    @State private var startNewPairSides: [LensSide] = [.both]

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var inUsePairs: [LensPair] {
        allPairs.filter { $0.status == .inUse }
    }

    private var reservePairs: [LensPair] {
        allPairs.filter { $0.status == .reserve }
    }

    private var lastCleaning: CaseCleaning? { cleanings.first }

    private var dashboardSummary: String? {
        guard let first = inUsePairs.first else { return nil }
        let status = LensStatisticsService.usageStatus(
            usesRemaining: first.usesRemaining,
            maximumUses: first.maximumUses,
            goodBelowPercent: settings.healthGoodBelowPercent,
            warningBelowPercent: settings.healthWarningBelowPercent,
            criticalBelowPercent: settings.healthCriticalBelowPercent
        )
        var parts = ["\(greeting). \(status.label) — \(first.usesRemaining) utilização(ões) restante(s)."]
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

    /// Lados disponíveis para iniciar um novo par — sempre todos os do modo atual, já que dá
    /// para escolher entre usar agora (rebaixa o par em uso do mesmo lado para reserva) ou
    /// guardar como reserva.
    private var startableSides: [LensSide] {
        settings.trackingMode == .individual ? [.right, .left] : [.both]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if inUsePairs.isEmpty && reservePairs.isEmpty {
                        emptyState
                    } else {
                        if let dashboardSummary {
                            Text(dashboardSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if inUsePairs.count > 1 {
                            registerAllButton
                        }
                        ForEach(inUsePairs) { pair in
                            LensPairCardView(
                                pair: pair,
                                lastCleaning: lastCleaning,
                                settings: settings,
                                onRegisterUsage: { registerUsage(for: pair) },
                                onFinishPair: { pairToFinish = pair },
                                onEdit: { pairToEdit = pair },
                                onShowDiary: { pairForDiary = pair },
                                onDelete: { viewModel.deletePair(pair, context: modelContext) },
                                onDemoteToReserve: { viewModel.demoteToReserve(pair, context: modelContext) },
                                wearingSessionPairID: viewModel.wearingSessionPairID,
                                onToggleWearingSession: { viewModel.toggleWearingSession(for: pair, settings: settings) }
                            )
                        }
                        if !reservePairs.isEmpty {
                            reservesSection
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Minhas Lentes")
            .task { viewModel.refreshWearingSessionState() }
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
                Text("O limite de utilizações de um dos pares foi atingido. Nada foi registrado — substitua as lentes antes de tentar de novo.")
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
                "Já existe uma utilização registrada nesta data em pelo menos um par. Registrar mesmo assim, em todos os pares deste lote?",
                isPresented: $viewModel.showDuplicateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Registrar mesmo assim") {
                    viewModel.confirmDuplicateRegistration(settings: settings, context: modelContext)
                }
                Button("Cancelar", role: .cancel) {
                    viewModel.cancelDuplicateRegistration()
                }
            }
            .alert("Excluir par?", isPresented: Binding(
                get: { pairToDelete != nil },
                set: { if !$0 { pairToDelete = nil } }
            )) {
                Button("Cancelar", role: .cancel) { pairToDelete = nil }
                Button("Excluir permanentemente", role: .destructive) {
                    if let pair = pairToDelete {
                        viewModel.deletePair(pair, context: modelContext)
                    }
                    pairToDelete = nil
                }
            } message: {
                Text("Apaga o par e todos os usos registrados nele. Diferente de encerrar, não pode ser desfeito.")
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
                StartNewPairSheet(defaultMaximumUses: settings.maximumUses, availableSides: startNewPairSides) { name, startDate, maximumUses, side, asReserve in
                    viewModel.startNewPair(
                        name: name,
                        startDate: startDate,
                        maximumUses: maximumUses,
                        trackingMode: settings.trackingMode,
                        side: side,
                        asReserve: asReserve,
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
                "Nenhum par cadastrado",
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
            viewModel.registerUsageForAllInUsePairs(inUsePairs, settings: settings, context: modelContext)
        } label: {
            Label("Registrar uso hoje (todos os pares)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var reservesSection: some View {
        SectionCard(title: "Reservas") {
            VStack(spacing: 10) {
                ForEach(reservePairs) { pair in
                    reserveRow(for: pair)
                    if pair.id != reservePairs.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func reserveRow(for pair: LensPair) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pair.name)
                    .font(.subheadline.weight(.medium))
                Text("\(pair.usesRemaining) de \(pair.maximumUses) usos restantes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Usar agora") {
                viewModel.promoteToInUse(pair, context: modelContext)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Menu {
                Button("Editar par", systemImage: "pencil") { pairToEdit = pair }
                Button("Ver diário do par", systemImage: "book.pages") { pairForDiary = pair }
                Button("Encerrar par", systemImage: "arrow.triangle.2.circlepath", role: .destructive) { pairToFinish = pair }
                Button("Excluir par", systemImage: "trash", role: .destructive) { pairToDelete = pair }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Mais opções para \(pair.name)")
        }
    }

    private func registerUsage(for pair: LensPair) {
        viewModel.registerUsageToday(for: pair, side: pair.side, settings: settings, context: modelContext)
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
