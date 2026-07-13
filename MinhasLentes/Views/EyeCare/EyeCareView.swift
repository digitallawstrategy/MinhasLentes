import SwiftUI
import SwiftData

/// Tela de Oftalmologista e Consultas: profissionais de referência e agenda. O app nunca
/// sugere diagnóstico — apenas ajuda a acompanhar contatos e prazos de retorno.
struct EyeCareView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EyeCareProfessional.name) private var professionals: [EyeCareProfessional]
    @Query(sort: \EyeAppointment.date, order: .reverse) private var appointments: [EyeAppointment]
    @Query private var allSettings: [AppSettings]

    @State private var viewModel = EyeCareViewModel()
    @State private var showAddProfessional = false
    @State private var professionalToEdit: EyeCareProfessional?
    @State private var professionalToDelete: EyeCareProfessional?
    @State private var showScheduleAppointment = false
    @State private var appointmentToEdit: EyeAppointment?
    @State private var appointmentToDelete: EyeAppointment?

    private var settings: AppSettings {
        allSettings.first ?? AppSettings()
    }

    private var scheduledAppointments: [EyeAppointment] {
        appointments.filter { $0.status == .scheduled }.sorted { $0.date < $1.date }
    }

    private var pastAppointments: [EyeAppointment] {
        appointments.filter { $0.status != .scheduled }
    }

    var body: some View {
        NavigationStack {
        List {
            Section {
                Text("Siga sempre a recomendação do seu oftalmologista. Este aplicativo não sugere diagnóstico — apenas ajuda a acompanhar contatos e prazos.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Profissionais") {
                if professionals.isEmpty {
                    Text("Nenhum profissional cadastrado.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(professionals) { professional in
                        professionalRow(for: professional)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { professionalToDelete = professional }
                                Button("Editar") { professionalToEdit = professional }
                                    .tint(AppColor.primary)
                            }
                    }
                }
                Button {
                    showAddProfessional = true
                } label: {
                    Label("Adicionar profissional", systemImage: "person.crop.circle.badge.plus")
                }
            }

            Section("Consultas agendadas") {
                if scheduledAppointments.isEmpty {
                    Text("Nenhuma consulta agendada.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(scheduledAppointments) { appointment in
                        appointmentRow(for: appointment)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { appointmentToDelete = appointment }
                                Button("Editar") { appointmentToEdit = appointment }
                                    .tint(AppColor.primary)
                                Button("Cancelar") {
                                    Task { await viewModel.cancelAppointment(appointment, context: modelContext) }
                                }
                                .tint(AppColor.warning)
                                Button("Realizada") {
                                    Task { await viewModel.markCompleted(appointment, context: modelContext) }
                                }
                                .tint(AppColor.success)
                            }
                    }
                }
                Button {
                    showScheduleAppointment = true
                } label: {
                    Label("Agendar consulta", systemImage: "calendar.badge.plus")
                }
            }

            if !pastAppointments.isEmpty {
                Section("Histórico de consultas") {
                    ForEach(pastAppointments) { appointment in
                        appointmentRow(for: appointment)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Excluir", role: .destructive) { appointmentToDelete = appointment }
                                Button("Editar") { appointmentToEdit = appointment }
                                    .tint(AppColor.primary)
                            }
                    }
                }
            }
        }
        .navigationTitle("Consultas")
        .sheet(isPresented: $showAddProfessional) {
            AddOrEditProfessionalSheet(professional: nil) { name, clinic, phone, whatsapp, email, address, notes in
                viewModel.addProfessional(name: name, clinic: clinic, phone: phone, whatsapp: whatsapp, email: email, address: address, notes: notes, context: modelContext)
            }
        }
        .sheet(item: $professionalToEdit) { professional in
            AddOrEditProfessionalSheet(professional: professional) { name, clinic, phone, whatsapp, email, address, notes in
                viewModel.editProfessional(professional, name: name, clinic: clinic, phone: phone, whatsapp: whatsapp, email: email, address: address, notes: notes, context: modelContext)
            }
        }
        .sheet(item: $professionalToDelete) { professional in
            ConfirmDeleteByTypingSheet(
                title: "Excluir profissional",
                message: "Isso exclui permanentemente \(professional.name) dos seus contatos. O histórico de consultas com ele(a) é preservado, sem o vínculo."
            ) {
                viewModel.deleteProfessional(professional, context: modelContext)
            }
        }
        .sheet(isPresented: $showScheduleAppointment) {
            AddOrEditAppointmentSheet(appointment: nil, professionals: professionals, defaultFollowUpMonths: settings.defaultAppointmentIntervalMonths) { date, type, notes, prescription, attachment, followUp, professional in
                Task {
                    await viewModel.scheduleAppointment(
                        date: date, type: type, notes: notes, prescription: prescription, attachmentData: attachment,
                        recommendedFollowUpMonths: followUp, professional: professional, settings: settings, context: modelContext
                    )
                }
            }
        }
        .sheet(item: $appointmentToEdit) { appointment in
            AddOrEditAppointmentSheet(appointment: appointment, professionals: professionals, defaultFollowUpMonths: settings.defaultAppointmentIntervalMonths) { date, type, notes, prescription, attachment, followUp, professional in
                Task {
                    await viewModel.editAppointment(
                        appointment, date: date, type: type, notes: notes, prescription: prescription,
                        attachmentData: attachment, recommendedFollowUpMonths: followUp, professional: professional,
                        settings: settings, context: modelContext
                    )
                }
            }
        }
        .alert("Excluir consulta?", isPresented: Binding(
            get: { appointmentToDelete != nil },
            set: { if !$0 { appointmentToDelete = nil } }
        )) {
            Button("Cancelar", role: .cancel) { appointmentToDelete = nil }
            Button("Excluir", role: .destructive) {
                if let appointment = appointmentToDelete {
                    Task { await viewModel.deleteAppointment(appointment, context: modelContext) }
                }
                appointmentToDelete = nil
            }
        }
        .alert(
            "Não foi possível concluir a ação",
            isPresented: Binding(
                get: { viewModel.presentedError != nil },
                set: { if !$0 { viewModel.presentedError = nil } }
            ),
            presenting: viewModel.presentedError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
        }
    }

    private func professionalRow(for professional: EyeCareProfessional) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(professional.name)
                .font(AppTypography.subheadlineMedium)
            if let clinic = professional.clinic, !clinic.isEmpty {
                Text(clinic)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 20) {
                if let phone = professional.phone, !phone.isEmpty {
                    Button {
                        openURL(telURL(phone))
                    } label: {
                        Label("Ligar", systemImage: "phone.fill")
                    }
                    .font(AppTypography.caption)
                }
                if let whatsapp = professional.whatsapp, !whatsapp.isEmpty {
                    Button {
                        openURL(whatsAppURL(whatsapp))
                    } label: {
                        Label("WhatsApp", systemImage: "message.fill")
                    }
                    .font(AppTypography.caption)
                }
                if let address = professional.address, !address.isEmpty {
                    Button {
                        openURL(mapsURL(address))
                    } label: {
                        Label("Mapas", systemImage: "map.fill")
                    }
                    .font(AppTypography.caption)
                }
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }

    private func appointmentRow(for appointment: EyeAppointment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(appointment.type.displayName)
                    .font(AppTypography.subheadlineMedium)
                Spacer()
                Text(appointment.status.displayName)
                    .font(AppTypography.captionSemibold)
                    .foregroundStyle(appointment.status == .scheduled ? AppColor.primary : .secondary)
            }
            Text(DateFormatting.shortWithTime.string(from: appointment.date))
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
            if let professional = appointment.professional {
                Text(professional.name)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = appointment.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func openURL(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    private func telURL(_ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return URL(string: "tel://\(digits)")
    }

    private func whatsAppURL(_ whatsapp: String) -> URL? {
        let digits = whatsapp.filter(\.isNumber)
        return URL(string: "https://wa.me/\(digits)")
    }

    private func mapsURL(_ address: String) -> URL? {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "http://maps.apple.com/?address=\(encoded)")
    }
}

#Preview {
    EyeCareView()
        .modelContainer(PreviewData.container)
}
