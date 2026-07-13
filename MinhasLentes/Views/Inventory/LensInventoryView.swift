import SwiftUI
import SwiftData

/// Tela dedicada de gerenciamento do estoque de lentes — caixas compradas, distintas dos pares
/// em uso. Editar/excluir sempre a um gesto de distância (deslizar); excluir exige digitar a
/// palavra de confirmação, por ser um "produto" e uma ação permanente.
struct LensInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LensInventoryItem.createdAt, order: .reverse) private var items: [LensInventoryItem]
    @Query private var allSettings: [AppSettings]

    @State private var viewModel = LensInventoryViewModel()
    @State private var showAddItem = false
    @State private var itemToEdit: LensInventoryItem?
    @State private var itemToDelete: LensInventoryItem?

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var availableItems: [LensInventoryItem] { items.filter { $0.status == .available } }
    private var exhaustedItems: [LensInventoryItem] { items.filter { $0.status == .exhausted } }

    private var totalRight: Int { LensInventoryStatisticsService.totalRemainingQuantity(items: availableItems, side: .right) }
    private var totalLeft: Int { LensInventoryStatisticsService.totalRemainingQuantity(items: availableItems, side: .left) }
    private var totalBoth: Int { LensInventoryStatisticsService.totalRemainingQuantity(items: availableItems, side: .both) }
    private var nearestExpiry: Date? { LensInventoryStatisticsService.nearestExpiry(items: availableItems) }
    private var lowStockItems: [LensInventoryItem] { availableItems.filter(LensInventoryStatisticsService.isLowStock) }
    private var itemsNearExpiry: [LensInventoryItem] {
        LensInventoryStatisticsService.itemsNearExpiry(items: availableItems, withinDays: 30)
    }

    private var totalAvailable: Int { totalRight + totalLeft + totalBoth }

    var body: some View {
        List {
            if !availableItems.isEmpty {
                Section("Resumo") {
                    MetricStrip(items: [
                        MetricStripItem(value: "\(totalAvailable)", label: "Disponíveis", tone: .success),
                        MetricStripItem(
                            value: nearestExpiry.map { DateFormatting.short.string(from: $0) } ?? "—",
                            label: "Próxima validade"
                        ),
                        MetricStripItem(
                            value: "\(lowStockItems.count)", label: "Estoque baixo",
                            tone: lowStockItems.isEmpty ? .neutral : .warning
                        ),
                    ])
                    .padding(.vertical, AppSpacing.xxs)
                    if !itemsNearExpiry.isEmpty {
                        InfoBanner(
                            systemImage: "calendar.badge.exclamationmark",
                            text: itemsNearExpiry.count == 1
                                ? "1 caixa perto da validade nos próximos 30 dias."
                                : "\(itemsNearExpiry.count) caixas perto da validade nos próximos 30 dias.",
                            tone: .warning
                        )
                    }
                }
            }
            Section("Disponível") {
                if availableItems.isEmpty {
                    Text("Nenhum item disponível no estoque.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableItems) { item in
                        NavigationLink {
                            LensInventoryItemDetailView(item: item, settings: settings, viewModel: viewModel)
                        } label: {
                            row(for: item)
                        }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { itemToDelete = item }
                                Button("Editar") { itemToEdit = item }
                                    .tint(AppColor.primary)
                            }
                    }
                }
                Button {
                    showAddItem = true
                } label: {
                    Label("Adicionar ao estoque", systemImage: "plus.circle")
                }
            }

            if !exhaustedItems.isEmpty {
                Section("Esgotado") {
                    ForEach(exhaustedItems) { item in
                        NavigationLink {
                            LensInventoryItemDetailView(item: item, settings: settings, viewModel: viewModel)
                        } label: {
                            row(for: item)
                        }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { itemToDelete = item }
                                Button("Editar") { itemToEdit = item }
                                    .tint(AppColor.primary)
                            }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .tabBarScrollInset()
        .background(AmbientBackground())
        .navigationTitle("Estoque de lentes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddItem) {
            AddOrEditLensInventoryItemSheet(item: nil) { brand, model, od, os, side, lot, expiry, initialQuantity, _, photo, notes in
                Task {
                    await viewModel.addItem(
                        brand: brand, model: model, prescriptionOD: od, prescriptionOS: os, side: side,
                        lot: lot, expiryDate: expiry, initialQuantity: initialQuantity, photoData: photo, notes: notes,
                        settings: settings, context: modelContext
                    )
                }
            }
        }
        .sheet(item: $itemToEdit) { item in
            AddOrEditLensInventoryItemSheet(item: item) { brand, model, od, os, side, lot, expiry, initialQuantity, remainingQuantity, photo, notes in
                Task {
                    await viewModel.editItem(
                        item, brand: brand, model: model, prescriptionOD: od, prescriptionOS: os, side: side,
                        lot: lot, expiryDate: expiry, initialQuantity: initialQuantity, remainingQuantity: remainingQuantity,
                        photoData: photo, notes: notes, settings: settings, context: modelContext
                    )
                }
            }
        }
        .sheet(item: $itemToDelete) { item in
            ConfirmDeleteByTypingSheet(
                title: "Excluir item",
                message: "Isso exclui permanentemente o registro de \(item.brand) \(item.model) do estoque."
            ) {
                Task { await viewModel.deleteItem(item, context: modelContext) }
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

    private func tone(for item: LensInventoryItem) -> AppStatusTone {
        if item.isExpired { return .critical }
        if LensInventoryStatisticsService.isLowStock(item) { return .warning }
        return .success
    }

    private func row(for item: LensInventoryItem) -> some View {
        AppListRow(
            systemImage: "tray.full",
            leadingImage: item.photoData.flatMap(UIImage.init(data:)),
            tone: tone(for: item),
            title: "\(item.brand) — \(item.model)",
            subtitle: "\(item.side.displayName) · \(item.remainingQuantity) de \(item.initialQuantity) \(Pluralization.word(item.initialQuantity, "unidade", "unidades"))",
            trailingText: item.expiryDate.map { date in
                let text = DateFormatting.short.string(from: date)
                return item.isExpired ? "\(text) (vencida)" : text
            },
            trailingTone: item.expiryDate != nil ? tone(for: item) : nil
        )
    }
}

#Preview {
    NavigationStack {
        LensInventoryView()
    }
    .modelContainer(PreviewData.container)
}
