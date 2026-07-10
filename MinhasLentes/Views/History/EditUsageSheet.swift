import SwiftUI

/// Formulário para corrigir a data, o lado ou a observação de um uso já registrado.
struct EditUsageSheet: View {
    let usage: LensUsage
    let allowSideSelection: Bool
    let onSave: (_ date: Date, _ side: LensSide, _ notes: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var side: LensSide
    @State private var notes: String

    init(usage: LensUsage, allowSideSelection: Bool, onSave: @escaping (Date, LensSide, String?) -> Void) {
        self.usage = usage
        self.allowSideSelection = allowSideSelection
        self.onSave = onSave
        _date = State(initialValue: usage.date)
        _side = State(initialValue: usage.side)
        _notes = State(initialValue: usage.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Editar uso") {
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    if allowSideSelection {
                        Picker("Lado", selection: $side) {
                            ForEach(LensSide.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                    }
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Editar uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(date, side, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                }
            }
        }
    }
}
