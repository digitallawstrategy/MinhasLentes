import SwiftUI
import SwiftData

/// Aba Lentes: informações detalhadas e gerenciamento completo dos pares — em uso, reservas,
/// estoque, edição, encerramento, lixeira, diário e histórico. O registro rápido de "uso hoje"
/// e a sessão "estou usando as lentes" moram na aba Início; aqui é onde se olha o detalhe de
/// cada par e se administra o que existe.
struct LensPairsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensPair.sequenceNumber) private var allPairs: [LensPair]
    @Query private var allSettings: [AppSettings]
    @Query(sort: \CaseCleaning.cleaningDate, order: .reverse) private var cleanings: [CaseCleaning]
    @Query(sort: \LensInventoryItem.createdAt, order: .reverse) private var inventoryItems: [LensInventoryItem]

    @State private var viewModel = LensPairsViewModel()
    @State private var router = AppRouter.shared
    @State private var pairToFinish: LensPair?
    @State private var pairToEdit: LensPair?
    @State private var pairForDiary: LensPair?
    @State private var pairToTrash: LensPair?
    @State private var showStartNewPair = false
    @State private var startNewPairSides: [LensSide] = [.both]
    #if DEBUG
    @State private var uiTestShowInventory = false
    #endif

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var inUsePairs: [LensPair] {
        allPairs.filter { $0.status == .inUse && $0.deletedAt == nil }
    }

    private var availableInventoryItems: [LensInventoryItem] {
        inventoryItems.filter { $0.status == .available && $0.remainingQuantity > 0 }
    }

    // Mesmas métricas já usadas no "Resumo" de `LensInventoryView` — não uma segunda leitura dos
    // números, só uma reexibição resumida deles aqui.
    private var totalRight: Int { LensInventoryStatisticsService.totalRemainingQuantity(items: availableInventoryItems, side: .right) }
    private var totalLeft: Int { LensInventoryStatisticsService.totalRemainingQuantity(items: availableInventoryItems, side: .left) }
    private var totalBoth: Int { LensInventoryStatisticsService.totalRemainingQuantity(items: availableInventoryItems, side: .both) }
    private var totalAvailable: Int { totalRight + totalLeft + totalBoth }
    private var nearestInventoryExpiry: Date? { LensInventoryStatisticsService.nearestExpiry(items: availableInventoryItems) }
    private var lowStockCount: Int { availableInventoryItems.filter(LensInventoryStatisticsService.isLowStock).count }

    private var reservePairs: [LensPair] {
        allPairs.filter { $0.status == .reserve && $0.deletedAt == nil }
    }

    private var finishedPairsCount: Int {
        allPairs.filter { $0.status == .finished && $0.deletedAt == nil }.count
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
                VStack(spacing: AppSpacing.md) {
                    inventoryCard
                    if finishedPairsCount > 0 {
                        pairHistoryLink
                    }
                    if inUsePairs.isEmpty && reservePairs.isEmpty {
                        EmptyStateView(
                            title: "Nenhum par cadastrado",
                            systemImage: "eyeglasses",
                            description: "Inicie um novo par de lentes para começar a registrar os usos.",
                            actionTitle: "Iniciar novo par",
                            actionSystemImage: "plus.circle.fill"
                        ) {
                            startNewPairSides = startableSides
                            showStartNewPair = true
                        }
                        .padding(.top, AppSpacing.xl)
                    } else {
                        dashboardContent
                    }
                }
                .padding(.horizontal)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.sm)
            }
            .tabBarScrollInset()
            .background(AmbientBackground())
            .navigationTitle("Lentes")
            .task {
                viewModel.refreshWearingSessionState(context: modelContext)
                openPendingPairIfNeeded()
                #if DEBUG
                if UITestSupport.requestedRoute() == .estoque {
                    uiTestShowInventory = true
                }
                #endif
            }
            .onChange(of: router.pendingPairID) { _, _ in
                openPendingPairIfNeeded()
            }
            #if DEBUG
            .navigationDestination(isPresented: $uiTestShowInventory) {
                LensInventoryView()
            }
            #endif
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
                Text("Some da aba Lentes e das reservas, mas fica recuperável na Lixeira (Mais → Dados) por \(LensPairService.trashRetentionDays) dias.")
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
                StartNewPairSheet(
                    defaultMaximumUses: settings.maximumUses,
                    availableSides: startNewPairSides,
                    availableInventoryItems: availableInventoryItems
                ) { name, startDate, maximumUses, side, asReserve, inventorySelections in
                    Task {
                        await viewModel.startNewPair(
                            name: name,
                            startDate: startDate,
                            maximumUses: maximumUses,
                            trackingMode: settings.trackingMode,
                            side: side,
                            asReserve: asReserve,
                            inventorySelections: inventorySelections,
                            context: modelContext
                        )
                    }
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

    /// Card de resumo, não uma linha de navegação pequena — o estoque é parte importante do
    /// sistema, não um apêndice. Mesmas métricas já usadas no "Resumo" de `LensInventoryView`.
    private var inventoryCard: some View {
        AppCard {
            SectionHeader("Estoque de lentes")
            if availableInventoryItems.isEmpty {
                Text("Nenhum item disponível no estoque.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                MetricStrip(items: [
                    MetricStripItem(value: "\(totalAvailable)", label: "Disponíveis", tone: .success),
                    MetricStripItem(
                        value: nearestInventoryExpiry.map { DateFormatting.short.string(from: $0) } ?? "—",
                        label: "Próxima validade"
                    ),
                    MetricStripItem(
                        value: "\(lowStockCount)", label: "Estoque baixo",
                        tone: lowStockCount == 0 ? .neutral : .warning
                    ),
                ])
                .padding(.vertical, AppSpacing.xxs)
                HStack(spacing: AppSpacing.md) {
                    Text("OD: \(totalRight)")
                    Text("OE: \(totalLeft)")
                    Text("Ambos: \(totalBoth)")
                }
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            }
            NavigationLink {
                LensInventoryView()
            } label: {
                Text("Ver estoque")
            }
            .font(AppTypography.subheadline)
            .padding(.top, AppSpacing.xxs)
        }
    }

    private var pairHistoryLink: some View {
        NavigationLink {
            LensPairHistoryView()
        } label: {
            HStack {
                Label("Histórico de pares", systemImage: "clock.arrow.circlepath")
                    .font(AppTypography.subheadlineMedium)
                Spacer()
                Text("\(finishedPairsCount)")
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.xxs)
    }

    @ViewBuilder
    private var dashboardContent: some View {
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
        ForEach(inUsePairs) { pair in
            LensPairCardView(
                pair: pair,
                settings: settings,
                onFinishPair: { pairToFinish = pair },
                onEdit: { pairToEdit = pair },
                onShowDiary: { pairForDiary = pair },
                onMoveToTrash: { viewModel.moveToTrash(pair, context: modelContext) },
                onDemoteToReserve: { viewModel.demoteToReserve(pair, context: modelContext) },
                wearingSessionPairID: viewModel.wearingSessionPairID
            )
        }
    }

    private var noPairInUseNotice: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "tray.and.arrow.up")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Nenhum par em uso")
                .font(AppTypography.headline)
            Text("Ative uma das reservas abaixo, ou inicie um par novo pelo botão + no topo.")
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
    }

    private var reservesSection: some View {
        AppCard {
            SectionHeader("Reservas")
            ForEach(reservePairs) { pair in
                reserveRow(for: pair)
                if pair.id != reservePairs.last?.id {
                    Divider()
                }
            }
        }
    }

    private func reserveRow(for pair: LensPair) -> some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pair.name)
                    .font(AppTypography.subheadlineMedium)
                Text("\(pair.usesRemaining) de \(pair.maximumUses) usos restantes")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SecondaryActionButton(title: "Usar agora", fullWidth: false, compact: true) {
                viewModel.promoteToInUse(pair, context: modelContext)
            }
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
    LensPairsView()
        .modelContainer(PreviewData.container)
}
