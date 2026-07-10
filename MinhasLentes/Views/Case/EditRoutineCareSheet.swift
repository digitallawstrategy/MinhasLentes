import SwiftUI

/// Formulário para corrigir a data, os detalhes ou a observação de um cuidado diário já registrado.
struct EditRoutineCareSheet: View {
    let log: RoutineCareLog
    let onSave: (_ date: Date, _ discardedSolution: Bool, _ cleanedCase: Bool, _ airDried: Bool, _ notes: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var discardedSolution: Bool
    @State private var cleanedCase: Bool
    @State private var airDried: Bool
    @State private var notes: String

    init(
        log: RoutineCareLog,
        onSave: @escaping (Date, Bool, Bool, Bool, String?) -> Void
    ) {
        self.log = log
        self.onSave = onSave
        _date = State(initialValue: log.date)
        _discardedSolution = State(initialValue: log.discardedSolution)
        _cleanedCase = State(initialValue: log.cleanedCase)
        _airDried = State(initialValue: log.airDried)
        _notes = State(initialValue: log.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Editar cuidado diário") {
                    DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Descartei a solução usada", isOn: $discardedSolution)
                    Toggle("Limpei o estojo", isOn: $cleanedCase)
                    Toggle("Deixei secar ao ar livre", isOn: $airDried)
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Editar cuidado diário")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(date, discardedSolution, cleanedCase, airDried, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
