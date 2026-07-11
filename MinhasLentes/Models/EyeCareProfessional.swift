import Foundation
import SwiftData

/// Um profissional de saúde ocular (oftalmologista, optometrista) — contato de referência,
/// não um registro de evento. Excluir é permanente (exige confirmação digitada na UI), já que
/// perder o contato de um profissional é uma perda real, não um log substituível.
@Model
final class EyeCareProfessional {
    var id: UUID = UUID()
    var name: String = ""
    var clinic: String?
    var phone: String?
    var whatsapp: String?
    var email: String?
    var address: String?
    var notes: String?
    var createdAt: Date = Date()

    /// Encerrar a consulta nunca apaga o profissional referenciado — apenas desfaz o vínculo
    /// (`.nullify`), preservando o histórico de consultas mesmo que o profissional seja excluído.
    @Relationship(deleteRule: .nullify, inverse: \EyeAppointment.professional)
    var appointments: [EyeAppointment]? = []

    init(
        id: UUID = UUID(),
        name: String,
        clinic: String? = nil,
        phone: String? = nil,
        whatsapp: String? = nil,
        email: String? = nil,
        address: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.clinic = clinic
        self.phone = phone
        self.whatsapp = whatsapp
        self.email = email
        self.address = address
        self.notes = notes
        self.createdAt = Date()
    }
}
