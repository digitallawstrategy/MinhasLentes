import SwiftUI

/// Formulário para corrigir a data ou a observação de uma limpeza do estojo já registrada.
struct EditCleaningSheet: View {
    let cleaning: CaseCleaning
    let onSave: (_ date: Date, _ notes: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var notes: String

    init(cleaning: CaseCleaning, onSave: @escaping (Date, String?) -> Void) {
        self.cleaning = cleaning
        self.onSave = onSave
        _date = State(initialValue: cleaning.cleaningDate)
        _notes = State(initialValue: cleaning.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Data da limpeza", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Editar limpeza")
                } footer: {
                    Text("Os avisos de limpeza serão recalculados automaticamente com a nova data.")
                }
            }
            .navigationTitle("Editar limpeza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(date, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
