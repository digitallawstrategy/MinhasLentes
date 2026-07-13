import SwiftUI

/// Detalhe de um profissional de saúde ocular, em modo leitura — tocar no corpo da linha em
/// `EyeCareView` abre aqui. Antes desta tela, Profissionais era a única lista de entidade
/// cadastrada do app sem nenhuma forma de ver o registro completo (só editar via swipe).
/// Ligar/WhatsApp/Mapas continuam como atalhos na própria linha da lista; aqui é o retrato
/// completo dos dados, sem truncamento.
struct ProfessionalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let professional: EyeCareProfessional
    let viewModel: EyeCareViewModel

    @State private var showEdit = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Nome", value: professional.name)
                if let clinic = professional.clinic, !clinic.isEmpty {
                    LabeledContent("Clínica", value: clinic)
                }
                if let phone = professional.phone, !phone.isEmpty {
                    LabeledContent("Telefone", value: phone)
                }
                if let whatsapp = professional.whatsapp, !whatsapp.isEmpty {
                    LabeledContent("WhatsApp", value: whatsapp)
                }
                if let email = professional.email, !email.isEmpty {
                    LabeledContent("E-mail", value: email)
                }
                if let address = professional.address, !address.isEmpty {
                    LabeledContent("Endereço", value: address)
                }
            }

            if let notes = professional.notes, !notes.isEmpty {
                Section("Observação") {
                    Text(notes)
                }
            }
        }
        .navigationTitle(professional.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Editar", systemImage: "pencil") { showEdit = true }
                    Button("Excluir", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Mais opções para \(professional.name)")
            }
        }
        .sheet(isPresented: $showEdit) {
            AddOrEditProfessionalSheet(professional: professional) { name, clinic, phone, whatsapp, email, address, notes in
                viewModel.editProfessional(
                    professional, name: name, clinic: clinic, phone: phone, whatsapp: whatsapp,
                    email: email, address: address, notes: notes, context: modelContext
                )
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            ConfirmDeleteByTypingSheet(
                title: "Excluir profissional",
                message: "Isso exclui permanentemente \(professional.name) dos seus contatos. O histórico de consultas com ele(a) é preservado, sem o vínculo."
            ) {
                viewModel.deleteProfessional(professional, context: modelContext)
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfessionalDetailView(
            professional: EyeCareProfessional(name: "Dra. Ana Souza", clinic: "Clínica Visão", phone: "+55 11 99999-0000"),
            viewModel: EyeCareViewModel()
        )
    }
    .modelContainer(PreviewData.container)
}
