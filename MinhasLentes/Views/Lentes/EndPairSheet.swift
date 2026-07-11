import SwiftUI

/// Formulário para encerrar ou substituir antecipadamente um par (ou lado) de lentes.
struct EndPairSheet: View {
    let pair: LensPair
    let onConfirm: (_ endDate: Date, _ reason: DiscardReason, _ notes: String?, _ startNewPairAfter: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var endDate: Date
    @State private var reason: DiscardReason
    @State private var notes = ""
    @State private var startNewPairAfter = true
    @State private var showFinalConfirmation = false

    init(pair: LensPair, onConfirm: @escaping (Date, DiscardReason, String?, Bool) -> Void) {
        self.pair = pair
        self.onConfirm = onConfirm
        _endDate = State(initialValue: Date())
        _reason = State(initialValue: pair.hasReachedLimit ? .usageLimitReached : .other)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Encerrar ou substituir \(pair.name)") {
                    DatePicker("Data de encerramento", selection: $endDate, displayedComponents: .date)
                    Picker("Motivo", selection: $reason) {
                        ForEach(DiscardReason.allCases) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Toggle("Iniciar novo par em seguida", isOn: $startNewPairAfter)
                } footer: {
                    Text("O histórico deste par é preservado e continuará disponível em Histórico.")
                }
            }
            .navigationTitle("Encerrar par")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        showFinalConfirmation = true
                    }
                }
            }
            .confirmationDialog(
                "Confirmar encerramento de \(pair.name)?",
                isPresented: $showFinalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Encerrar par", role: .destructive) {
                    onConfirm(endDate, reason, notes.isEmpty ? nil : notes, startNewPairAfter)
                    dismiss()
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }
}
