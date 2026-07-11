import SwiftUI

/// Formulário de adicionar/editar um profissional de saúde ocular.
struct AddOrEditProfessionalSheet: View {
    let professional: EyeCareProfessional?
    let onSave: (
        _ name: String, _ clinic: String?, _ phone: String?, _ whatsapp: String?,
        _ email: String?, _ address: String?, _ notes: String?
    ) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var clinic: String
    @State private var phone: String
    @State private var whatsapp: String
    @State private var email: String
    @State private var address: String
    @State private var notes: String

    init(professional: EyeCareProfessional?, onSave: @escaping (String, String?, String?, String?, String?, String?, String?) -> Void) {
        self.professional = professional
        self.onSave = onSave
        _name = State(initialValue: professional?.name ?? "")
        _clinic = State(initialValue: professional?.clinic ?? "")
        _phone = State(initialValue: professional?.phone ?? "")
        _whatsapp = State(initialValue: professional?.whatsapp ?? "")
        _email = State(initialValue: professional?.email ?? "")
        _address = State(initialValue: professional?.address ?? "")
        _notes = State(initialValue: professional?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome", text: $name)
                    TextField("Clínica (opcional)", text: $clinic)
                }
                Section("Contato") {
                    TextField("Telefone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("WhatsApp", text: $whatsapp)
                        .keyboardType(.phonePad)
                    TextField("E-mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Endereço", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(professional == nil ? "Adicionar profissional" : "Editar profissional")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(
                            name.isEmpty ? "Profissional" : name, clinic.isEmpty ? nil : clinic,
                            phone.isEmpty ? nil : phone, whatsapp.isEmpty ? nil : whatsapp,
                            email.isEmpty ? nil : email, address.isEmpty ? nil : address, notes.isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}
