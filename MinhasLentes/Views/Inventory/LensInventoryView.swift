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

    var body: some View {
        List {
            if !availableItems.isEmpty {
                Section("Resumo") {
                    if totalRight > 0 {
                        StatRow(label: "Olho direito", value: "\(totalRight) lente(s)")
                    }
                    if totalLeft > 0 {
                        StatRow(label: "Olho esquerdo", value: "\(totalLeft) lente(s)")
                    }
                    if totalBoth > 0 {
                        StatRow(label: "Ambos os olhos", value: "\(totalBoth) lente(s)")
                    }
                    if let nearestExpiry {
                        StatRow(label: "Validade mais próxima", value: DateFormatting.short.string(from: nearestExpiry))
                    }
                    if !itemsNearExpiry.isEmpty {
                        StatRow(label: "Caixas perto da validade", value: "\(itemsNearExpiry.count)")
                    }
                    if !lowStockItems.isEmpty {
                        StatRow(label: "Estoque baixo", value: "\(lowStockItems.count) item(ns)")
                    }
                }
            }
            Section("Disponível") {
                if availableItems.isEmpty {
                    Text("Nenhum item disponível no estoque.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableItems) { item in
                        row(for: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { itemToDelete = item }
                                Button("Editar") { itemToEdit = item }
                                    .tint(.blue)
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
                        row(for: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { itemToDelete = item }
                                Button("Editar") { itemToEdit = item }
                                    .tint(.blue)
                            }
                    }
                }
            }
        }
        .navigationTitle("Estoque de lentes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddItem) {
            AddOrEditLensInventoryItemSheet(item: nil) { brand, model, od, os, side, lot, expiry, quantity, photo, notes in
                Task {
                    await viewModel.addItem(
                        brand: brand, model: model, prescriptionOD: od, prescriptionOS: os, side: side,
                        lot: lot, expiryDate: expiry, initialQuantity: quantity, photoData: photo, notes: notes,
                        settings: settings, context: modelContext
                    )
                }
            }
        }
        .sheet(item: $itemToEdit) { item in
            AddOrEditLensInventoryItemSheet(item: item) { brand, model, od, os, side, lot, expiry, quantity, photo, notes in
                Task {
                    await viewModel.editItem(
                        item, brand: brand, model: model, prescriptionOD: od, prescriptionOS: os, side: side,
                        lot: lot, expiryDate: expiry, remainingQuantity: quantity, photoData: photo, notes: notes,
                        settings: settings, context: modelContext
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

    private func row(for item: LensInventoryItem) -> some View {
        HStack(spacing: 10) {
            if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(item.brand) — \(item.model)")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(item.side.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(item.remainingQuantity) de \(item.initialQuantity) unidade(s) restante(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let expiryDate = item.expiryDate {
                    Text("Validade: \(DateFormatting.short.string(from: expiryDate))\(item.isExpired ? " — vencida" : "")")
                        .font(.caption)
                        .foregroundStyle(item.isExpired ? Color.orange : Color.secondary)
                }
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        LensInventoryView()
    }
    .modelContainer(PreviewData.container)
}
