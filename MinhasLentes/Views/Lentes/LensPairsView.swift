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

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var inUsePairs: [LensPair] {
        allPairs.filter { $0.status == .inUse && $0.deletedAt == nil }
    }

    private var availableInventoryItems: [LensInventoryItem] {
        inventoryItems.filter { $0.status == .available && $0.remainingQuantity > 0 }
    }

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
                VStack(spacing: 16) {
                    inventoryLink
                    if finishedPairsCount > 0 {
                        pairHistoryLink
                    }
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
            .navigationTitle("Lentes")
            .task {
                viewModel.refreshWearingSessionState(context: modelContext)
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
                ) { name, startDate, maximumUses, side, asReserve, inventoryItem in
                    Task {
                        await viewModel.startNewPair(
                            name: name,
                            startDate: startDate,
                            maximumUses: maximumUses,
                            trackingMode: settings.trackingMode,
                            side: side,
                            asReserve: asReserve,
                            inventoryItem: inventoryItem,
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

    private var inventoryLink: some View {
        NavigationLink {
            LensInventoryView()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Label("Estoque de lentes", systemImage: "shippingbox")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if !availableInventoryItems.isEmpty {
                    Text(inventorySummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private var inventorySummaryText: String {
        var parts = [availableInventoryItems.count == 1 ? "1 disponível" : "\(availableInventoryItems.count) disponíveis"]
        let nearExpiry = LensInventoryStatisticsService.itemsNearExpiry(items: availableInventoryItems, withinDays: 30)
        if !nearExpiry.isEmpty {
            parts.append(nearExpiry.count == 1 ? "1 vencendo em breve" : "\(nearExpiry.count) vencendo em breve")
        }
        return parts.joined(separator: " · ")
    }

    private var pairHistoryLink: some View {
        NavigationLink {
            LensPairHistoryView()
        } label: {
            HStack {
                Label("Histórico de pares", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(finishedPairsCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
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
