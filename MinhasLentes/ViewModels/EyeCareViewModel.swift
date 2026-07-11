import Foundation
import Observation
import SwiftData

/// Estado e ações da tela Oftalmologista e Consultas: profissionais e agenda.
@MainActor
@Observable
final class EyeCareViewModel {
    var presentedError: IdentifiableError?

    // MARK: - Profissionais

    func addProfessional(
        name: String, clinic: String?, phone: String?, whatsapp: String?, email: String?,
        address: String?, notes: String?, context: ModelContext
    ) {
        do {
            try EyeCareProfessionalService.addProfessional(
                name: name, clinic: clinic, phone: phone, whatsapp: whatsapp, email: email,
                address: address, notes: notes, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func editProfessional(
        _ professional: EyeCareProfessional, name: String, clinic: String?, phone: String?, whatsapp: String?,
        email: String?, address: String?, notes: String?, context: ModelContext
    ) {
        do {
            try EyeCareProfessionalService.editProfessional(
                professional, name: name, clinic: clinic, phone: phone, whatsapp: whatsapp,
                email: email, address: address, notes: notes, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func deleteProfessional(_ professional: EyeCareProfessional, context: ModelContext) {
        do {
            try EyeCareProfessionalService.deleteProfessional(professional, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    // MARK: - Consultas

    func scheduleAppointment(
        date: Date, type: EyeAppointmentType, notes: String?, prescription: String?, attachmentData: Data?,
        recommendedFollowUpMonths: Int, professional: EyeCareProfessional?, settings: AppSettings, context: ModelContext
    ) async {
        do {
            _ = try await EyeAppointmentService.scheduleAppointment(
                date: date, type: type, notes: notes, prescription: prescription, attachmentData: attachmentData,
                recommendedFollowUpMonths: recommendedFollowUpMonths, professional: professional,
                settings: settings, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func editAppointment(
        _ appointment: EyeAppointment, date: Date, type: EyeAppointmentType, notes: String?, prescription: String?,
        attachmentData: Data?, recommendedFollowUpMonths: Int, professional: EyeCareProfessional?,
        settings: AppSettings, context: ModelContext
    ) async {
        do {
            try await EyeAppointmentService.editAppointment(
                appointment, date: date, type: type, notes: notes, prescription: prescription,
                attachmentData: attachmentData, recommendedFollowUpMonths: recommendedFollowUpMonths,
                professional: professional, settings: settings, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func markCompleted(_ appointment: EyeAppointment, context: ModelContext) async {
        do {
            try await EyeAppointmentService.markCompleted(appointment, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func cancelAppointment(_ appointment: EyeAppointment, context: ModelContext) async {
        do {
            try await EyeAppointmentService.cancelAppointment(appointment, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func deleteAppointment(_ appointment: EyeAppointment, context: ModelContext) async {
        do {
            try await EyeAppointmentService.deleteAppointment(appointment, context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }
}
