import Foundation
import SwiftData
import WidgetKit

/// CRUD dos profissionais de saúde ocular — contatos de referência, sem ciclo de vida ou
/// notificações associadas (diferente de estojo/solução/estoque).
@MainActor
enum EyeCareProfessionalService {

    enum ServiceError: LocalizedError {
        case persistenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar o profissional. \(detail)"
            }
        }
    }

    static func allProfessionals(context: ModelContext) throws -> [EyeCareProfessional] {
        let descriptor = FetchDescriptor<EyeCareProfessional>(sortBy: [SortDescriptor(\.name)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    private static func save(context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            do {
                try context.save()
            } catch {
                throw ServiceError.persistenceFailed(error.localizedDescription)
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    @discardableResult
    static func addProfessional(
        name: String, clinic: String?, phone: String?, whatsapp: String?, email: String?,
        address: String?, notes: String?, context: ModelContext
    ) throws -> EyeCareProfessional {
        let professional = EyeCareProfessional(
            name: name, clinic: clinic, phone: phone, whatsapp: whatsapp, email: email, address: address, notes: notes
        )
        context.insert(professional)
        logEvent(.professionalAdded, descriptionText: "\(name) adicionado(a) como profissional de saúde ocular.", context: context)
        try save(context: context)
        return professional
    }

    static func editProfessional(
        _ professional: EyeCareProfessional, name: String, clinic: String?, phone: String?, whatsapp: String?,
        email: String?, address: String?, notes: String?, context: ModelContext
    ) throws {
        professional.name = name
        professional.clinic = clinic
        professional.phone = phone
        professional.whatsapp = whatsapp
        professional.email = email
        professional.address = address
        professional.notes = notes
        logEvent(.professionalEdited, descriptionText: "\(name) editado(a).", context: context)
        try save(context: context)
    }

    static func deleteProfessional(_ professional: EyeCareProfessional, context: ModelContext) throws {
        let name = professional.name
        context.delete(professional)
        logEvent(.professionalDeleted, descriptionText: "\(name) excluído(a). O histórico de consultas com ele(a) foi preservado.", context: context)
        try save(context: context)
    }

    private static func logEvent(_ type: HistoryEventType, descriptionText: String, context: ModelContext) {
        let event = HistoryEvent(eventType: type, eventDate: Date(), descriptionText: descriptionText)
        context.insert(event)
    }
}
