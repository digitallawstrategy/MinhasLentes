import Foundation
import SwiftData

enum EyeAppointmentStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case scheduled
    case completed
    case canceled

    var displayName: String {
        switch self {
        case .scheduled: return "Agendada"
        case .completed: return "Realizada"
        case .canceled: return "Cancelada"
        }
    }
}

enum EyeAppointmentType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case routine
    case followUp
    case emergency
    case examOnly
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .routine: return "Consulta de rotina"
        case .followUp: return "Retorno"
        case .emergency: return "Urgência"
        case .examOnly: return "Exame"
        case .other: return "Outro"
        }
    }
}

/// Uma consulta com um profissional de saúde ocular — agendada, realizada ou cancelada. O app
/// nunca sugere diagnóstico: apenas ajuda a acompanhar a agenda e lembra de seguir a orientação
/// do próprio profissional.
@Model
final class EyeAppointment {
    var id: UUID = UUID()
    var date: Date = Date()
    var typeRawValue: String = EyeAppointmentType.routine.rawValue
    var notes: String?
    /// Texto livre da receita — não estruturado, porque a notação varia por profissional.
    var prescription: String?
    /// Anexo opcional (foto da receita/pedido de exame), fora do arquivo principal do banco.
    @Attribute(.externalStorage) var attachmentData: Data?
    /// Prazo recomendado até a próxima consulta, em meses — copiado de `AppSettings` no
    /// momento do agendamento, mas ajustável por consulta (o profissional pode recomendar um
    /// prazo diferente do padrão).
    var recommendedFollowUpMonths: Int = 12
    var statusRawValue: String = EyeAppointmentStatus.scheduled.rawValue
    var createdAt: Date = Date()

    var professional: EyeCareProfessional?

    init(
        id: UUID = UUID(),
        date: Date,
        type: EyeAppointmentType,
        notes: String? = nil,
        prescription: String? = nil,
        attachmentData: Data? = nil,
        recommendedFollowUpMonths: Int,
        professional: EyeCareProfessional?
    ) {
        self.id = id
        self.date = date
        self.typeRawValue = type.rawValue
        self.notes = notes
        self.prescription = prescription
        self.attachmentData = attachmentData
        self.recommendedFollowUpMonths = recommendedFollowUpMonths
        self.statusRawValue = EyeAppointmentStatus.scheduled.rawValue
        self.professional = professional
        self.createdAt = Date()
    }

    var type: EyeAppointmentType {
        get { EyeAppointmentType(rawValue: typeRawValue) ?? .routine }
        set { typeRawValue = newValue.rawValue }
    }

    var status: EyeAppointmentStatus {
        get { EyeAppointmentStatus(rawValue: statusRawValue) ?? .scheduled }
        set { statusRawValue = newValue.rawValue }
    }
}
