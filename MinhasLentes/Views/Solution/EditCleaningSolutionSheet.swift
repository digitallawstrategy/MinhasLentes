import SwiftUI

/// Formulário para corrigir os dados de um frasco de solução de limpeza já registrado — sem
/// alterar se ele está ativo ou finalizado.
struct EditCleaningSolutionSheet: View {
    let solution: CleaningSolution
    let onSave: (
        _ brand: String, _ product: String, _ lot: String?, _ purchaseDate: Date?, _ openedDate: Date,
        _ printedExpiryDate: Date?, _ postOpeningShelfLifeDays: Int, _ initialVolumeML: Int?,
        _ remainingVolumeML: Int?, _ notes: String?
    ) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var brand: String
    @State private var product: String
    @State private var lot: String
    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var openedDate: Date
    @State private var hasPrintedExpiry: Bool
    @State private var printedExpiryDate: Date
    @State private var postOpeningShelfLifeDays: Int
    @State private var hasInitialVolume: Bool
    @State private var initialVolumeML: Int
    @State private var hasRemainingVolume: Bool
    @State private var remainingVolumeML: Int
    @State private var notes: String

    init(solution: CleaningSolution, onSave: @escaping (String, String, String?, Date?, Date, Date?, Int, Int?, Int?, String?) -> Void) {
        self.solution = solution
        self.onSave = onSave
        _brand = State(initialValue: solution.brand)
        _product = State(initialValue: solution.product)
        _lot = State(initialValue: solution.lot ?? "")
        _hasPurchaseDate = State(initialValue: solution.purchaseDate != nil)
        _purchaseDate = State(initialValue: solution.purchaseDate ?? Date())
        _openedDate = State(initialValue: solution.openedDate)
        _hasPrintedExpiry = State(initialValue: solution.printedExpiryDate != nil)
        _printedExpiryDate = State(initialValue: solution.printedExpiryDate ?? Date())
        _postOpeningShelfLifeDays = State(initialValue: solution.postOpeningShelfLifeDays)
        _hasInitialVolume = State(initialValue: solution.initialVolumeML != nil)
        _initialVolumeML = State(initialValue: solution.initialVolumeML ?? 120)
        _hasRemainingVolume = State(initialValue: solution.remainingVolumeML != nil)
        _remainingVolumeML = State(initialValue: solution.remainingVolumeML ?? solution.initialVolumeML ?? 120)
        _notes = State(initialValue: solution.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Editar solução") {
                    TextField("Marca", text: $brand)
                    TextField("Produto", text: $product)
                    TextField("Lote (opcional)", text: $lot)
                }
                Section {
                    DatePicker("Data de abertura", selection: $openedDate, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Informar data de compra", isOn: $hasPurchaseDate)
                    if hasPurchaseDate {
                        DatePicker("Data de compra", selection: $purchaseDate, displayedComponents: .date)
                    }
                }
                Section {
                    Toggle("Informar validade impressa no frasco", isOn: $hasPrintedExpiry)
                    if hasPrintedExpiry {
                        DatePicker("Validade impressa", selection: $printedExpiryDate, displayedComponents: .date)
                    }
                    Stepper("Validade após aberto: \(postOpeningShelfLifeDays) dias", value: $postOpeningShelfLifeDays, in: 1...365)
                }
                Section {
                    Toggle("Informar volume inicial", isOn: $hasInitialVolume)
                    if hasInitialVolume {
                        Stepper("Volume inicial: \(initialVolumeML) ml", value: $initialVolumeML, in: 10...1000, step: 10)
                    }
                    Toggle("Informar volume restante", isOn: $hasRemainingVolume)
                    if hasRemainingVolume {
                        Stepper("Volume restante: \(remainingVolumeML) ml", value: $remainingVolumeML, in: 0...1000, step: 10)
                    }
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Editar solução")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(
                            brand.isEmpty ? solution.brand : brand,
                            product,
                            lot.isEmpty ? nil : lot,
                            hasPurchaseDate ? purchaseDate : nil,
                            openedDate,
                            hasPrintedExpiry ? printedExpiryDate : nil,
                            postOpeningShelfLifeDays,
                            hasInitialVolume ? initialVolumeML : nil,
                            hasRemainingVolume ? remainingVolumeML : nil,
                            notes.isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}
