import SwiftUI

/// Formulário para corrigir a data de início, o intervalo ou a observação de um ciclo de estojo
/// já registrado — sem alterar se ele está ativo ou substituído.
struct EditLensCaseSheet: View {
    let lensCase: LensCase
    let onSave: (_ startDate: Date, _ intervalDays: Int, _ notes: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var intervalDays: Int
    @State private var notes: String

    init(lensCase: LensCase, onSave: @escaping (Date, Int, String?) -> Void) {
        self.lensCase = lensCase
        self.onSave = onSave
        _startDate = State(initialValue: lensCase.startDate)
        _intervalDays = State(initialValue: lensCase.intervalDays)
        _notes = State(initialValue: lensCase.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Editar ciclo do estojo") {
                    DatePicker("Data de início", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Substituir em: \(intervalDays) dias", value: $intervalDays, in: 1...365)
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Editar ciclo")
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
