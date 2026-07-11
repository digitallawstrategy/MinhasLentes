import SwiftUI

/// Formulário para abrir um novo frasco de solução de limpeza — usado tanto para o primeiro
/// frasco quanto para substituir o atual (encerrado automaticamente pelo `CleaningSolutionService`).
struct StartOrReplaceSolutionSheet: View {
    let isReplacing: Bool
    let onSave: (
        _ brand: String, _ product: String, _ lot: String?, _ purchaseDate: Date?, _ openedDate: Date,
        _ printedExpiryDate: Date?, _ postOpeningShelfLifeDays: Int, _ initialVolumeML: Int?, _ notes: String?
    ) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var brand = ""
    @State private var product = ""
    @State private var lot = ""
    @State private var hasPurchaseDate = false
    @State private var purchaseDate = Date()
    @State private var openedDate = Date()
    @State private var hasPrintedExpiry = false
    @State private var printedExpiryDate = Date()
    @State private var postOpeningShelfLifeDays = 90
    @State private var hasVolume = false
    @State private var initialVolumeML = 120
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(isReplacing ? "Substituir solução" : "Nova solução") {
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
                } footer: {
                    Text("Use sempre os prazos indicados pelo fabricante no rótulo. O descarte recomendado é a data mais próxima entre os dois.")
                }
                Section {
                    Toggle("Informar volume", isOn: $hasVolume)
                    if hasVolume {
                        Stepper("Volume inicial: \(initialVolumeML) ml", value: $initialVolumeML, in: 10...1000, step: 10)
                    }
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isReplacing ? "Substituir solução" : "Nova solução")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(
                            brand.isEmpty ? "Solução" : brand,
                            product,
                            lot.isEmpty ? nil : lot,
                            hasPurchaseDate ? purchaseDate : nil,
                            openedDate,
                            hasPrintedExpiry ? printedExpiryDate : nil,
                            postOpeningShelfLifeDays,
                            hasVolume ? initialVolumeML : nil,
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
