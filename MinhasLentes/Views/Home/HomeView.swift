import SwiftUI
import SwiftData

/// Aba Início: resumo do(s) par(es) em uso, reservas disponíveis e registro de uso com um toque.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensPair.sequenceNumber) private var allPairs: [LensPair]
    @Query private var allSettings: [AppSettings]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]

    @State private var viewModel = HomeViewModel()
    @State private var caseViewModel = CaseViewModel()
    @State private var router = AppRouter.shared
    @State private var pairToFinish: LensPair?
    @State private var pairToEdit: LensPair?
    @State private var pairForDiary: LensPair?
    @State private var pairToTrash: LensPair?
    @State private var showStartNewPair = false
    @State private var startNewPairSides: [LensSide] = [.both]

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var inUsePairs: [LensPair] {
        allPairs.filter { $0.status == .inUse && $0.deletedAt == nil }
    }

    private var reservePairs: [LensPair] {
        allPairs.filter { $0.status == .reserve && $0.deletedAt == nil }
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
        return "\(greeting). \(status.label) — \(first.usesRemaining) utilização(ões) restante(s)."
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
                        dashboardContent
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Minhas Lentes")
            .task {
                viewModel.refreshWearingSessionState()
                openPendingPairIfNeeded()
            }
            .onChange(of: router.pendingPairID) { _, _ in
                openPendingPairIfNeeded()
            }
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
                } else if caseViewModel.showUndoToast, let message = caseViewModel.toastMessage {
                    ConfirmationToast(message: message, actionTitle: "Desfazer") {
                        Task { await caseViewModel.undoLastRegisteredCleaning(settings: settings, context: modelContext) }
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: viewModel.showUndoToast)
            .animation(.snappy, value: caseViewModel.showUndoToast)
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
            .alert(
                "Não foi possível concluir a ação",
                isPresented: Binding(
                    get: { caseViewModel.presentedError != nil },
                    set: { if !$0 { caseViewModel.presentedError = nil } }
                ),
                presenting: caseViewModel.presentedError
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
            .alert("Mover \(pairToTrash?.name ?? "par") para a lixeira?", isPresented: Binding(
                get: { pairToTrash != nil },
                set: { if !$0 { pairToTrash = nil } }
            )) {
                Button("Cancelar", role: .cancel) { pairToTrash = nil }
                Button("Mover para a lixeira", role: .destructive) {
                    if let pair = pairToTrash {
                        viewModel.moveToTrash(pair, context: modelContext)
                    }
                    pairToTrash = nil
                }
            } message: {
                Text("Some da Home e das reservas, mas fica recuperável na Lixeira (Configurações → Dados) por \(LensPairService.trashRetentionDays) dias.")
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

    @ViewBuilder
    private var dashboardContent: some View {
        if let dashboardSummary {
            Text(dashboardSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if inUsePairs.isEmpty {
            noPairInUseNotice
        } else {
            inUsePairsContent
        }
        if !reservePairs.isEmpty {
            reservesSection
        }
    }

    @ViewBuilder
    private var inUsePairsContent: some View {
        if inUsePairs.count > 1 {
            registerAllButton
        }
        ForEach(inUsePairs) { pair in
            LensPairCardView(
                pair: pair,
                settings: settings,
                onRegisterUsage: { registerUsage(for: pair) },
                onFinishPair: { pairToFinish = pair },
                onEdit: { pairToEdit = pair },
                onShowDiary: { pairForDiary = pair },
                onMoveToTrash: { viewModel.moveToTrash(pair, context: modelContext) },
                onDemoteToReserve: { viewModel.demoteToReserve(pair, context: modelContext) },
                wearingSessionPairID: viewModel.wearingSessionPairID,
                onToggleWearingSession: { viewModel.toggleWearingSession(for: pair, settings: settings) }
            )
        }
        CaseSummaryCardView(
            lastCleaning: lastCleaning,
            settings: settings,
            onRegisterCleaningToday: {
                Task { await caseViewModel.registerCleaningToday(settings: settings, context: modelContext) }
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Nenhum par cadastrado",
                systemImage: "eyeglasses",
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

    private var noPairInUseNotice: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.up")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Nenhum par em uso")
                .font(.headline)
            Text("Ative uma das reservas abaixo, ou inicie um par novo pelo botão + no topo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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
                Button("Mover para a lixeira", systemImage: "trash", role: .destructive) { pairToTrash = pair }
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

    /// Abre o Diário do par indicado por um deep link do widget (`minhaslentes://pair/<uuid>`),
    /// se houver um pendente e o par ainda existir.
    private func openPendingPairIfNeeded() {
        guard let pendingID = router.pendingPairID else { return }
        router.pendingPairID = nil
        guard let pair = allPairs.first(where: { $0.id == pendingID }) else { return }
        pairForDiary = pair
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
