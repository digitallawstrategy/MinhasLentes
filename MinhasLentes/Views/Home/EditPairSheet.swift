import SwiftUI

/// Formulário para corrigir identificação, data de início e limite de usos de um par —
/// inclusive um par já encerrado, sem precisar reabri-lo só para acertar um dado.
struct EditPairSheet: View {
    let pair: LensPair
    let onSave: (_ name: String, _ startDate: Date, _ maximumUses: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var startDate: Date
    @State private var maximumUses: Int

    init(pair: LensPair, onSave: @escaping (String, Date, Int) -> Void) {
        self.pair = pair
        self.onSave = onSave
        _name = State(initialValue: pair.name)
        _startDate = State(initialValue: pair.startDate)
        _maximumUses = State(initialValue: pair.maximumUses)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Editar par") {
                    TextField("Nome", text: $name)
                    DatePicker("Data de início", selection: $startDate, displayedComponents: .date)
                    Stepper("Limite de usos: \(maximumUses)", value: $maximumUses, in: 1...500)
                }
            }
            .navigationTitle("Editar par")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(name, startDate, maximumUses)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
