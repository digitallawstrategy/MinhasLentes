import Foundation
import SwiftData
import WidgetKit

/// Regras de negócio da agenda de consultas oftalmológicas. Várias consultas podem estar
/// agendadas ao mesmo tempo (diferente de estojo/solução) — não há "só uma ativa por vez".
@MainActor
enum EyeAppointmentService {

    enum ServiceError: LocalizedError {
        case persistenceFailed(String)
        case notificationSchedulingFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível salvar a consulta. \(detail)"
            case .notificationSchedulingFailed(let detail):
                return "A consulta foi registrada, mas não foi possível agendar as notificações. \(detail)"
            }
        }
    }

    static func allAppointments(context: ModelContext) throws -> [EyeAppointment] {
        let descriptor = FetchDescriptor<EyeAppointment>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            throw ServiceError.persistenceFailed(error.localizedDescription)
        }
    }

    static func nextAppointment(context: ModelContext) throws -> EyeAppointment? {
        try allAppointments(context: context)
            .filter { $0.status == .scheduled && $0.date >= Date() }
            .sorted { $0.date < $1.date }
            .first
    }

    static func lastAppointment(context: ModelContext) throws -> EyeAppointment? {
        try allAppointments(context: context)
            .filter { $0.status == .completed }
            .first
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
    static func scheduleAppointment(
        date: Date,
        type: EyeAppointmentType,
        notes: String?,
        prescription: String?,
        attachmentData: Data?,
        recommendedFollowUpMonths: Int,
        professional: EyeCareProfessional?,
        settings: AppSettings,
        context: ModelContext
    ) async throws -> EyeAppointment {
        let appointment = EyeAppointment(
            date: date, type: type, notes: notes, prescription: prescription, attachmentData: attachmentData,
            recommendedFollowUpMonths: recommendedFollowUpMonths, professional: professional
        )
        context.insert(appointment)
        logEvent(
            .appointmentScheduled,
            date: date,
            descriptionText: "Consulta (\(type.displayName)) agendada para \(DateFormatting.short.string(from: date)).",
            context: context
        )
        try save(context: context)

        do {
            try await NotificationManager.shared.scheduleEyeAppointmentNotifications(
                for: appointment, professionalName: professional?.name, settings: settings
            )
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; a consulta permanece salva normalmente.
        } catch {
            let failureEvent = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Falha ao agendar notificações da consulta: \(error.localizedDescription)"
            )
            context.insert(failureEvent)
            try? context.save()
            throw ServiceError.notificationSchedulingFailed(error.localizedDescription)
        }

        return appointment
    }

    static func editAppointment(
        _ appointment: EyeAppointment,
        date: Date,
        type: EyeAppointmentType,
        notes: String?,
        prescription: String?,
        attachmentData: Data?,
        recommendedFollowUpMonths: Int,
        professional: EyeCareProfessional?,
        settings: AppSettings,
        context: ModelContext
    ) async throws {
        appointment.date = date
        appointment.type = type
        appointment.notes = notes
        appointment.prescription = prescription
        appointment.attachmentData = attachmentData
        appointment.recommendedFollowUpMonths = recommendedFollowUpMonths
        appointment.professional = professional
        logEvent(.appointmentEdited, date: date, descriptionText: "Consulta editada para \(DateFormatting.short.string(from: date)).", context: context)
        try save(context: context)

        await NotificationManager.shared.cancelEyeAppointmentNotifications(for: appointment.id)
        guard appointment.status == .scheduled else { return }
        do {
            try await NotificationManager.shared.scheduleEyeAppointmentNotifications(
                for: appointment, professionalName: professional?.name, settings: settings
            )
        } catch NotificationManager.NotificationError.authorizationDenied {
            // Usuário ainda não autorizou notificações; a edição permanece salva normalmente.
        } catch {
            let failureEvent = HistoryEvent(
                eventType: .settingsChanged,
                eventDate: Date(),
                descriptionText: "Falha ao reagendar notificações da consulta: \(error.localizedDescription)"
            )
            context.insert(failureEvent)
            try? context.save()
            throw ServiceError.notificationSchedulingFailed(error.localizedDescription)
        }
    }

    /// Marca a consulta como realizada e cancela os avisos pendentes (não há mais sentido em
    /// lembrar de uma consulta que já aconteceu).
    static func markCompleted(_ appointment: EyeAppointment, context: ModelContext) async throws {
        appointment.status = .completed
        logEvent(.appointmentCompleted, date: Date(), descriptionText: "Consulta de \(DateFormatting.short.string(from: appointment.date)) marcada como realizada.", context: context)
        try save(context: context)
        await NotificationManager.shared.cancelEyeAppointmentNotifications(for: appointment.id)
    }

    static func cancelAppointment(_ appointment: EyeAppointment, context: ModelContext) async throws {
        appointment.status = .canceled
        logEvent(.appointmentCanceled, date: Date(), descriptionText: "Consulta de \(DateFormatting.short.string(from: appointment.date)) cancelada.", context: context)
        try save(context: context)
        await NotificationManager.shared.cancelEyeAppointmentNotifications(for: appointment.id)
    }

    static func deleteAppointment(_ appointment: EyeAppointment, context: ModelContext) async throws {
        let id = appointment.id
        let date = appointment.date
        context.delete(appointment)
        logEvent(.appointmentDeleted, date: Date(), descriptionText: "Consulta de \(DateFormatting.short.string(from: date)) excluída.", context: context)
        try save(context: context)
        await NotificationManager.shared.cancelEyeAppointmentNotifications(for: id)
    }

    private static func logEvent(_ type: HistoryEventType, date: Date, descriptionText: String, context: ModelContext) {
        let event = HistoryEvent(eventType: type, eventDate: date, descriptionText: descriptionText)
        context.insert(event)
    }
}
