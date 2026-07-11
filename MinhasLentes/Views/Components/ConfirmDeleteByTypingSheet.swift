import SwiftUI

/// Confirmação reforçada para exclusões permanentes e sem volta: o botão destrutivo só fica
/// habilitado depois que o usuário digita a palavra de confirmação exatamente como pedido.
struct ConfirmDeleteByTypingSheet: View {
    let title: String
    let message: String
    var confirmationWord: String = "excluir"
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typedText = ""

    private var isConfirmed: Bool {
        typedText.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(confirmationWord) == .orderedSame
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    TextField("Digite \"\(confirmationWord)\"", text: $typedText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Esta ação não pode ser desfeita. Para confirmar, digite \"\(confirmationWord)\".")
                }
                Section {
                    Button("Excluir permanentemente", role: .destructive) {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(!isConfirmed)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
