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

    var body: some View {
        List {
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
