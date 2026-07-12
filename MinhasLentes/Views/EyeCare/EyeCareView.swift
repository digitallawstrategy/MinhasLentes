import SwiftUI
import SwiftData

/// Tela de Oftalmologista e Consultas: profissionais de referência e agenda. O app nunca
/// sugere diagnóstico — apenas ajuda a acompanhar contatos e prazos de retorno.
struct EyeCareView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    private var nextAppointment: EyeAppointment? { scheduledAppointments.first }
    private var otherScheduledAppointments: [EyeAppointment] { Array(scheduledAppointments.dropFirst()) }

    private var pastAppointments: [EyeAppointment] {
        appointments.filter { $0.status != .scheduled }
    }

    private func daysUntil(_ appointment: EyeAppointment) -> Int {
        LensStatisticsService.daysUntil(appointment.date)
    }

    private func tone(forDaysUntil days: Int) -> AppStatusTone {
        if days <= 0 { return .informative }
        if days <= settings.advanceReminderDays { return .warning }
        return .success
    }

    var body: some View {
        NavigationStack {
        List {
            Section("Próxima consulta") {
                if let nextAppointment {
                    nextAppointmentCard(for: nextAppointment)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Excluir", role: .destructive) { appointmentToDelete = nextAppointment }
                            Button("Editar") { appointmentToEdit = nextAppointment }
                                .tint(AppColor.primary)
                            Button("Cancelar") {
                                Task { await viewModel.cancelAppointment(nextAppointment, context: modelContext) }
                            }
                            .tint(AppColor.warning)
                            Button("Realizada") {
                                Task { await viewModel.markCompleted(nextAppointment, context: modelContext) }
                            }
                            .tint(AppColor.success)
                        }
                } else {
                    Text("Nenhuma consulta agendada.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showScheduleAppointment = true
                } label: {
                    Label("Agendar consulta", systemImage: "calendar.badge.plus")
                }
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

            if !otherScheduledAppointments.isEmpty {
                Section("Outras consultas agendadas") {
                    ForEach(otherScheduledAppointments) { appointment in
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

            Section {
                InfoBanner(text: "Siga sempre a recomendação do seu oftalmologista. Este aplicativo não sugere diagnóstico — apenas ajuda a acompanhar contatos e prazos.")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .tabBarScrollInset()
        .background(AmbientBackground())
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

    private func nextAppointmentCard(for appointment: EyeAppointment) -> some View {
        let days = daysUntil(appointment)
        let daysTone = tone(forDaysUntil: days)
        let badgeText = days > 0 ? "Em \(Pluralization.count(days, "dia", "dias"))" : (days == 0 ? "Hoje" : "Atrasada")
        let statusBadge = StatusBadge(text: badgeText, tone: daysTone, systemImage: "calendar")
        let accessibilityStatusBadge = StatusBadge(text: badgeText, tone: daysTone, systemImage: "calendar", lineLimit: nil)
        let titleBlock = VStack(alignment: .leading, spacing: 2) {
            Text(appointment.type.displayName)
                .font(AppTypography.headline)
            Text(DateFormatting.shortWithTime.string(from: appointment.date))
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
        }
        return AppCard(variant: .featured) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    titleBlock
                    // Mesmo sozinho na própria linha, sem nenhum vizinho disputando espaço, o
                    // selo truncava ("Falta...") em accessibility-XXXL — o texto simplesmente não
                    // cabe numa linha só nesse tamanho de fonte, nem com a tela inteira à
                    // disposição. `lineLimit: nil` deixa a pílula crescer em altura (2 linhas) em
                    // vez de truncar ou (com `.fixedSize()`, tentado antes) ficar maior que a tela
                    // e cortar visualmente.
                    accessibilityStatusBadge
                }
            } else {
                HStack(alignment: .top) {
                    titleBlock
                    Spacer(minLength: AppSpacing.xs)
                    statusBadge
                }
            }
            if let professional = appointment.professional {
                Text(professional.name)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let notes = appointment.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func professionalRow(for professional: EyeCareProfessional) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "person.crop.circle.fill")
                .font(.subheadline)
                .foregroundStyle(AppColor.primary)
                .frame(width: 36, height: 36)
                .background(AppColor.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(professional.name)
                    .font(AppTypography.subheadlineMedium)
                if let clinic = professional.clinic, !clinic.isEmpty {
                    Text(clinic)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: AppSpacing.md) {
                    if let phone = professional.phone, !phone.isEmpty {
                        quickActionButton(title: "Ligar", systemImage: "phone.fill") { openURL(telURL(phone)) }
                    }
                    if let whatsapp = professional.whatsapp, !whatsapp.isEmpty {
                        quickActionButton(title: "WhatsApp", systemImage: "message.fill") { openURL(whatsAppURL(whatsapp)) }
                    }
                    if let address = professional.address, !address.isEmpty {
                        quickActionButton(title: "Mapas", systemImage: "map.fill") { openURL(mapsURL(address)) }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private func quickActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(AppTypography.badge)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs)
                .background(AppColor.primary.opacity(0.12), in: Capsule())
                .foregroundStyle(AppColor.primary)
        }
        .buttonStyle(.plain)
    }

    private func appointmentRow(for appointment: EyeAppointment) -> some View {
        AppListRow(
            systemImage: "calendar",
            tone: appointment.status == .scheduled ? .informative : .neutral,
            title: appointment.type.displayName,
            subtitle: [DateFormatting.shortWithTime.string(from: appointment.date), appointment.professional?.name]
                .compactMap { $0 }
                .joined(separator: " · "),
            trailingText: appointment.status.displayName,
            trailingTone: appointment.status == .scheduled ? .informative : nil
        )
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
