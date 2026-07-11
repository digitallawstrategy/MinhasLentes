import SwiftUI
import PhotosUI

/// Formulário de adicionar/editar um item do estoque de lentes. `item == nil` significa
/// "adicionar" (pede quantidade inicial); um item existente pede a quantidade restante em vez
/// disso, já que a inicial não deve ser corrigida depois de unidades já terem sido usadas.
struct AddOrEditLensInventoryItemSheet: View {
    let item: LensInventoryItem?
    let onSave: (
        _ brand: String, _ model: String, _ prescriptionOD: String?, _ prescriptionOS: String?, _ side: LensSide,
        _ lot: String?, _ expiryDate: Date?, _ quantity: Int, _ photoData: Data?, _ notes: String?
    ) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var brand: String
    @State private var model: String
    @State private var prescriptionOD: String
    @State private var prescriptionOS: String
    @State private var side: LensSide
    @State private var lot: String
    @State private var hasExpiryDate: Bool
    @State private var expiryDate: Date
    @State private var quantity: Int
    @State private var notes: String
    @State private var photoData: Data?
    @State private var photoPickerItem: PhotosPickerItem?

    init(item: LensInventoryItem?, onSave: @escaping (String, String, String?, String?, LensSide, String?, Date?, Int, Data?, String?) -> Void) {
        self.item = item
        self.onSave = onSave
        _brand = State(initialValue: item?.brand ?? "")
        _model = State(initialValue: item?.model ?? "")
        _prescriptionOD = State(initialValue: item?.prescriptionOD ?? "")
        _prescriptionOS = State(initialValue: item?.prescriptionOS ?? "")
        _side = State(initialValue: item?.side ?? .both)
        _lot = State(initialValue: item?.lot ?? "")
        _hasExpiryDate = State(initialValue: item?.expiryDate != nil)
        _expiryDate = State(initialValue: item?.expiryDate ?? Date())
        _quantity = State(initialValue: item?.remainingQuantity ?? 1)
        _notes = State(initialValue: item?.notes ?? "")
        _photoData = State(initialValue: item?.photoData)
    }

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lente") {
                    TextField("Marca", text: $brand)
                    TextField("Modelo", text: $model)
                    Picker("Lado", selection: $side) {
                        ForEach(LensSide.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    TextField("Grau OD (opcional)", text: $prescriptionOD)
                    TextField("Grau OE (opcional)", text: $prescriptionOS)
                    TextField("Lote (opcional)", text: $lot)
                }

                Section {
                    Toggle("Informar validade", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker("Validade", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section {
                    Stepper(isEditing ? "Quantidade restante: \(quantity)" : "Quantidade inicial: \(quantity)", value: $quantity, in: 0...100)
                }

                Section("Foto (opcional)") {
                    PhotosPicker("Escolher foto", selection: $photoPickerItem, matching: .images)
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                        Button("Remover foto", role: .destructive) { self.photoData = nil }
                    }
                }

                Section {
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Editar item" : "Adicionar ao estoque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(
                            brand.isEmpty ? "Lente" : brand, model, prescriptionOD.isEmpty ? nil : prescriptionOD,
                            prescriptionOS.isEmpty ? nil : prescriptionOS, side, lot.isEmpty ? nil : lot,
                            hasExpiryDate ? expiryDate : nil, quantity, photoData, notes.isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                }
            }
            .task(id: photoPickerItem) {
                guard let photoPickerItem else { return }
                if let data = try? await photoPickerItem.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
        .presentationDetents([.large])
    }
}
