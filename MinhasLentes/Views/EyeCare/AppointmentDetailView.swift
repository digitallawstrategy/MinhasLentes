import SwiftUI

/// Detalhe de uma consulta, em modo leitura — tocar numa linha em `EyeCareView` abre aqui, em
/// vez de direto no formulário de edição (que continua existindo, reaberto pelo botão "Editar").
struct AppointmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let appointment: EyeAppointment
    let professionals: [EyeCareProfessional]
    let settings: AppSettings
    let viewModel: EyeCareViewModel

    @State private var showEdit = false
    @State private var showCancelConfirmation = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Tipo", value: appointment.type.displayName)
                LabeledContent("Data e horário", value: DateFormatting.shortWithTime.string(from: appointment.date))
                if let professional = appointment.professional {
                    LabeledContent("Profissional", value: professional.name)
                }
                LabeledContent("Status", value: appointment.status.displayName)
                LabeledContent("Retorno recomendado", value: "\(appointment.recommendedFollowUpMonths) meses")
            }

            if let prescription = appointment.prescription, !prescription.isEmpty {
                Section("Receita") {
                    Text(prescription)
                }
            }

            if let notes = appointment.notes, !notes.isEmpty {
                Section("Observações") {
                    Text(notes)
                }
            }

            if appointment.attachmentData != nil {
                Section("Anexo") {
                    ImageAttachmentPreview(data: appointment.attachmentData, accessibilityLabel: "Foto da receita ou pedido de exame")
                }
            }

            Section {
                Button("Editar") { showEdit = true }
                if appointment.status == .scheduled {
                    Button("Marcar como realizada") {
                        Task { await viewModel.markCompleted(appointment, context: modelContext) }
                    }
                    Button("Cancelar consulta", role: .destructive) { showCancelConfirmation = true }
                }
                Button("Excluir", role: .destructive) { showDeleteConfirmation = true }
            }
        }
        .navigationTitle(appointment.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            AddOrEditAppointmentSheet(
                appointment: appointment, professionals: professionals, defaultFollowUpMonths: settings.defaultAppointmentIntervalMonths
            ) { date, type, notes, prescription, attachment, followUp, professional in
                Task {
                    await viewModel.editAppointment(
                        appointment, date: date, type: type, notes: notes, prescription: prescription,
                        attachmentData: attachment, recommendedFollowUpMonths: followUp, professional: professional,
                        settings: settings, context: modelContext
                    )
                }
            }
        }
        .alert("Cancelar esta consulta?", isPresented: $showCancelConfirmation) {
            Button("Voltar", role: .cancel) {}
            Button("Cancelar consulta", role: .destructive) {
                Task { await viewModel.cancelAppointment(appointment, context: modelContext) }
            }
        }
        .alert("Excluir consulta?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                Task {
                    await viewModel.deleteAppointment(appointment, context: modelContext)
                    dismiss()
                }
            }
        }
    }
}
