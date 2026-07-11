import SwiftUI
import PhotosUI

/// Formulário de agendar/editar uma consulta. O app nunca sugere diagnóstico — apenas ajuda a
/// acompanhar a agenda.
struct AddOrEditAppointmentSheet: View {
    let appointment: EyeAppointment?
    let professionals: [EyeCareProfessional]
    let defaultFollowUpMonths: Int
    let onSave: (
        _ date: Date, _ type: EyeAppointmentType, _ notes: String?, _ prescription: String?,
        _ attachmentData: Data?, _ recommendedFollowUpMonths: Int, _ professional: EyeCareProfessional?
    ) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var type: EyeAppointmentType
    @State private var notes: String
    @State private var prescription: String
    @State private var recommendedFollowUpMonths: Int
    @State private var selectedProfessionalID: UUID?
    @State private var attachmentData: Data?
    @State private var attachmentPickerItem: PhotosPickerItem?

    init(
        appointment: EyeAppointment?,
        professionals: [EyeCareProfessional],
        defaultFollowUpMonths: Int,
        onSave: @escaping (Date, EyeAppointmentType, String?, String?, Data?, Int, EyeCareProfessional?) -> Void
    ) {
        self.appointment = appointment
        self.professionals = professionals
        self.defaultFollowUpMonths = defaultFollowUpMonths
        self.onSave = onSave
        _date = State(initialValue: appointment?.date ?? Date())
        _type = State(initialValue: appointment?.type ?? .routine)
        _notes = State(initialValue: appointment?.notes ?? "")
        _prescription = State(initialValue: appointment?.prescription ?? "")
        _recommendedFollowUpMonths = State(initialValue: appointment?.recommendedFollowUpMonths ?? defaultFollowUpMonths)
        _selectedProfessionalID = State(initialValue: appointment?.professional?.id)
        _attachmentData = State(initialValue: appointment?.attachmentData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Data e horário", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Tipo", selection: $type) {
                        ForEach(EyeAppointmentType.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    if !professionals.isEmpty {
                        Picker("Profissional", selection: $selectedProfessionalID) {
                            Text("Nenhum").tag(UUID?.none)
                            ForEach(professionals) { professional in
                                Text(professional.name).tag(Optional(professional.id))
                            }
                        }
                    }
                }

                Section {
                    Stepper("Retorno recomendado: \(recommendedFollowUpMonths) meses", value: $recommendedFollowUpMonths, in: 1...24)
                } footer: {
                    Text("Siga sempre a recomendação do seu oftalmologista quanto ao prazo de retorno.")
                }

                Section("Receita (opcional)") {
                    TextField("Receita", text: $prescription, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Anexo (opcional)") {
                    PhotosPicker("Escolher foto (receita/pedido)", selection: $attachmentPickerItem, matching: .images)
                    if let attachmentData, let uiImage = UIImage(data: attachmentData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                        Button("Remover anexo", role: .destructive) { self.attachmentData = nil }
                    }
                }

                Section {
                    TextField("Observação (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(appointment == nil ? "Agendar consulta" : "Editar consulta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let professional = professionals.first { $0.id == selectedProfessionalID }
                        onSave(
                            date, type, notes.isEmpty ? nil : notes, prescription.isEmpty ? nil : prescription,
                            attachmentData, recommendedFollowUpMonths, professional
                        )
                        dismiss()
                    }
                }
            }
            .task(id: attachmentPickerItem) {
                guard let attachmentPickerItem else { return }
                if let data = try? await attachmentPickerItem.loadTransferable(type: Data.self) {
                    attachmentData = data
                }
            }
        }
        .presentationDetents([.large])
    }
}
