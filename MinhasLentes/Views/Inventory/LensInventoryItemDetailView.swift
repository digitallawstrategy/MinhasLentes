import SwiftUI

/// Detalhe de um item do estoque, em modo leitura — tocar numa linha em `LensInventoryView` abre
/// aqui, em vez de direto no formulário de edição (que continua existindo, reaberto pelo botão
/// "Editar"). Excluir mantém a mesma confirmação por digitação já usada em `LensInventoryView`
/// (é um "produto" e uma ação permanente).
struct LensInventoryItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: LensInventoryItem
    let settings: AppSettings
    let viewModel: LensInventoryViewModel

    @State private var showEdit = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Marca", value: item.brand)
                LabeledContent("Modelo", value: item.model)
                LabeledContent("Lado", value: item.side.displayName)
                if let prescriptionOD = item.prescriptionOD, !prescriptionOD.isEmpty {
                    LabeledContent("Grau OD", value: prescriptionOD)
                }
                if let prescriptionOS = item.prescriptionOS, !prescriptionOS.isEmpty {
                    LabeledContent("Grau OE", value: prescriptionOS)
                }
                if let lot = item.lot, !lot.isEmpty {
                    LabeledContent("Lote", value: lot)
                }
                if let expiryDate = item.expiryDate {
                    LabeledContent("Validade", value: DateFormatting.short.string(from: expiryDate))
                }
                LabeledContent("Quantidade", value: "\(item.remainingQuantity) de \(item.initialQuantity)")
                LabeledContent("Status", value: item.status.displayName)
            }

            if let notes = item.notes, !notes.isEmpty {
                Section("Notas") {
                    Text(notes)
                }
            }

            if item.photoData != nil {
                Section("Foto") {
                    ImageAttachmentPreview(data: item.photoData, accessibilityLabel: "Foto da caixa de lentes")
                }
            }
        }
        .navigationTitle("\(item.brand) \(item.model)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Regra 4 da rodada de consistência: editar/excluir moram no toolbar, não como botões
            // soltos de `Form` com a mesma aparência das linhas informativas acima.
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Editar", systemImage: "pencil") { showEdit = true }
                    Button("Excluir", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Mais opções para \(item.brand) \(item.model)")
            }
        }
        .sheet(isPresented: $showEdit) {
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
        .sheet(isPresented: $showDeleteConfirmation) {
            ConfirmDeleteByTypingSheet(
                title: "Excluir item",
                message: "Isso exclui permanentemente o registro de \(item.brand) \(item.model) do estoque."
            ) {
                Task {
                    await viewModel.deleteItem(item, context: modelContext)
                    dismiss()
                }
            }
        }
    }
}
