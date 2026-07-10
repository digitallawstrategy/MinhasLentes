import SwiftUI

/// Formulário para iniciar um novo ciclo de estojo — usado tanto para o primeiro estojo quanto
/// para substituir o atual (que é encerrado automaticamente pelo `LensCaseService`).
struct StartOrReplaceCaseSheet: View {
    let isReplacing: Bool
    let defaultIntervalDays: Int
    let onSave: (_ startDate: Date, _ intervalDays: Int, _ notes: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()
    @State private var intervalDays: Int
    @State private var notes = ""

    init(isReplacing: Bool, defaultIntervalDays: Int, onSave: @escaping (Date, Int, String?) -> Void) {
        self.isReplacing = isReplacing
        self.defaultIntervalDays = defaultIntervalDays
        self.onSave = onSave
        _intervalDays = State(initialValue: defaultIntervalDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Data", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Substituir em: \(intervalDays) dias", value: $intervalDays, in: 1...365)
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text(isReplacing ? "Substituir estojo" : "Novo estojo")
                } footer: {
                    if isReplacing {
                        Text("O ciclo atual do estojo será encerrado automaticamente nesta data.")
                    } else {
                        Text("Marca o início do acompanhamento do estojo físico.")
                    }
                }
            }
            .navigationTitle(isReplacing ? "Substituir estojo" : "Novo estojo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(startDate, intervalDays, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
