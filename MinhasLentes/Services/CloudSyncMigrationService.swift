import Foundation
import SwiftData

/// Copia todos os dados do store local legado (sem CloudKit) para o novo store sincronizado —
/// usado uma única vez, na primeira execução em que há conta iCloud disponível. Função pura em
/// relação a onde os `ModelContext` vêm (não sabe se são um teste em memória ou o App Group de
/// verdade), para ser testável sem CloudKit real: só fetch de um contexto, insert no outro.
///
/// Preserva o `id: UUID` de cada registro (nunca gera um novo) — é assim que as relações entre
/// tipos são remontadas no destino (via um dicionário id → objeto novo) e é assim que rodar a
/// migração duas vezes seguidas não duplica nada: cada tipo busca os ids já existentes no
/// destino uma vez (fetch simples, sem `#Predicate` genérico — o macro precisa de keypaths
/// estáticos do tipo concreto, não de um cast via protocolo) e pula o que já está lá.
///
/// Ordem de migração respeita as dependências reais do schema (`AppSchemaV1`): tipos sem
/// relacionamento primeiro, depois os que referenciam outro tipo já migrado.
/// `HistoryEvent.lensPairID` é um `UUID` solto (não uma relação SwiftData de verdade — ver o
/// próprio modelo), então não precisa de mapeamento: como o id do `LensPair` migrado é sempre o
/// mesmo do original, a referência continua válida sozinha.
@MainActor
enum CloudSyncMigrationService {
    enum MigrationError: LocalizedError {
        case persistenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível migrar os dados para o armazenamento sincronizado. \(detail)"
            }
        }
    }

    struct MigrationSummary: Equatable {
        var pairsCopied = 0
        var usagesCopied = 0
        var wearSessionsCopied = 0
        var settingsCopied = 0
    }

    /// `true` se o contexto tem qualquer dado do usuário — usado por quem chama para decidir se
    /// vale a pena migrar (destino genuinamente vazio) ou se a origem não tem nada a migrar.
    static func hasAnyData(context: ModelContext) throws -> Bool {
        if try !context.fetch(FetchDescriptor<LensPair>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<AppSettings>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<EyeCareProfessional>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<LensInventoryItem>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<CaseCleaning>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<LensCase>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<RoutineCareLog>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<CleaningSolution>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<EyeAppointment>()).isEmpty { return true }
        if try !context.fetch(FetchDescriptor<HistoryEvent>()).isEmpty { return true }
        return false
    }

    @discardableResult
    static func migrate(from source: ModelContext, to destination: ModelContext) throws -> MigrationSummary {
        var summary = MigrationSummary()

        // MARK: Tipos independentes

        let existingSettingsIDs = Set(try destination.fetch(FetchDescriptor<AppSettings>()).map(\.id))
        for settings in try source.fetch(FetchDescriptor<AppSettings>()) where !existingSettingsIDs.contains(settings.id) {
            let copy = AppSettings(id: settings.id)
            copy.maximumUses = settings.maximumUses
            copy.cleaningIntervalDays = settings.cleaningIntervalDays
            copy.advanceReminderDays = settings.advanceReminderDays
            copy.notificationHour = settings.notificationHour
            copy.notificationMinute = settings.notificationMinute
            copy.allowMultipleUsesPerDay = settings.allowMultipleUsesPerDay
            copy.advanceReminderEnabled = settings.advanceReminderEnabled
            copy.deadlineReminderEnabled = settings.deadlineReminderEnabled
            copy.soundEnabled = settings.soundEnabled
            copy.badgeEnabled = settings.badgeEnabled
            copy.trackingModeRawValue = settings.trackingModeRawValue
            copy.hasCompletedOnboarding = settings.hasCompletedOnboarding
            copy.healthGoodBelowPercent = settings.healthGoodBelowPercent
            copy.healthWarningBelowPercent = settings.healthWarningBelowPercent
            copy.healthCriticalBelowPercent = settings.healthCriticalBelowPercent
            copy.wearingReminderHours = settings.wearingReminderHours
            copy.wearingExcessiveRepeatIntervalHours = settings.wearingExcessiveRepeatIntervalHours
            copy.caseReplacementIntervalDays = settings.caseReplacementIntervalDays
            copy.caseReminderEnabled = settings.caseReminderEnabled
            copy.caseOverdueReminderIntervalDays = settings.caseOverdueReminderIntervalDays
            copy.solutionReminderEnabled = settings.solutionReminderEnabled
            copy.solutionOverdueReminderIntervalDays = settings.solutionOverdueReminderIntervalDays
            copy.inventoryReminderEnabled = settings.inventoryReminderEnabled
            copy.appointmentReminderEnabled = settings.appointmentReminderEnabled
            copy.defaultAppointmentIntervalMonths = settings.defaultAppointmentIntervalMonths
            copy.dailyCareReminderEnabled = settings.dailyCareReminderEnabled
            copy.dailyCareReminderHour = settings.dailyCareReminderHour
            destination.insert(copy)
            summary.settingsCopied += 1
        }

        let existingCleaningIDs = Set(try destination.fetch(FetchDescriptor<CaseCleaning>()).map(\.id))
        for cleaning in try source.fetch(FetchDescriptor<CaseCleaning>()) where !existingCleaningIDs.contains(cleaning.id) {
            destination.insert(CaseCleaning(id: cleaning.id, cleaningDate: cleaning.cleaningDate, notes: cleaning.notes))
        }

        let existingCaseIDs = Set(try destination.fetch(FetchDescriptor<LensCase>()).map(\.id))
        for lensCase in try source.fetch(FetchDescriptor<LensCase>()) where !existingCaseIDs.contains(lensCase.id) {
            let copy = LensCase(id: lensCase.id, startDate: lensCase.startDate, intervalDays: lensCase.intervalDays, notes: lensCase.notes)
            copy.replacedAt = lensCase.replacedAt
            copy.statusRawValue = lensCase.statusRawValue
            copy.createdAt = lensCase.createdAt
            destination.insert(copy)
        }

        let existingRoutineCareIDs = Set(try destination.fetch(FetchDescriptor<RoutineCareLog>()).map(\.id))
        for log in try source.fetch(FetchDescriptor<RoutineCareLog>()) where !existingRoutineCareIDs.contains(log.id) {
            destination.insert(RoutineCareLog(
                id: log.id, date: log.date, discardedSolution: log.discardedSolution,
                cleanedCase: log.cleanedCase, airDried: log.airDried, notes: log.notes
            ))
        }

        let existingSolutionIDs = Set(try destination.fetch(FetchDescriptor<CleaningSolution>()).map(\.id))
        for solution in try source.fetch(FetchDescriptor<CleaningSolution>()) where !existingSolutionIDs.contains(solution.id) {
            let copy = CleaningSolution(
                id: solution.id, brand: solution.brand, product: solution.product, lot: solution.lot,
                purchaseDate: solution.purchaseDate, openedDate: solution.openedDate,
                printedExpiryDate: solution.printedExpiryDate, postOpeningShelfLifeDays: solution.postOpeningShelfLifeDays,
                initialVolumeML: solution.initialVolumeML, remainingVolumeML: solution.remainingVolumeML, notes: solution.notes
            )
            copy.statusRawValue = solution.statusRawValue
            copy.finishedAt = solution.finishedAt
            copy.createdAt = solution.createdAt
            destination.insert(copy)
        }

        var professionalsByID: [UUID: EyeCareProfessional] = [:]
        for professional in try destination.fetch(FetchDescriptor<EyeCareProfessional>()) {
            professionalsByID[professional.id] = professional
        }
        for professional in try source.fetch(FetchDescriptor<EyeCareProfessional>()) where professionalsByID[professional.id] == nil {
            let copy = EyeCareProfessional(
                id: professional.id, name: professional.name, clinic: professional.clinic, phone: professional.phone,
                whatsapp: professional.whatsapp, email: professional.email, address: professional.address, notes: professional.notes
            )
            destination.insert(copy)
            professionalsByID[professional.id] = copy
        }

        var inventoryItemsByID: [UUID: LensInventoryItem] = [:]
        for item in try destination.fetch(FetchDescriptor<LensInventoryItem>()) {
            inventoryItemsByID[item.id] = item
        }
        for item in try source.fetch(FetchDescriptor<LensInventoryItem>()) where inventoryItemsByID[item.id] == nil {
            let copy = LensInventoryItem(
                id: item.id, brand: item.brand, model: item.model, prescriptionOD: item.prescriptionOD,
                prescriptionOS: item.prescriptionOS, side: item.side, lot: item.lot, expiryDate: item.expiryDate,
                initialQuantity: item.initialQuantity, photoData: item.photoData, notes: item.notes
            )
            copy.remainingQuantity = item.remainingQuantity
            copy.statusRawValue = item.statusRawValue
            copy.createdAt = item.createdAt
            destination.insert(copy)
            inventoryItemsByID[item.id] = copy
        }

        // MARK: Dependem de EyeCareProfessional

        let existingAppointmentIDs = Set(try destination.fetch(FetchDescriptor<EyeAppointment>()).map(\.id))
        for appointment in try source.fetch(FetchDescriptor<EyeAppointment>()) where !existingAppointmentIDs.contains(appointment.id) {
            let professional = appointment.professional.flatMap { professionalsByID[$0.id] }
            let copy = EyeAppointment(
                id: appointment.id, date: appointment.date, type: appointment.type, notes: appointment.notes,
                prescription: appointment.prescription, attachmentData: appointment.attachmentData,
                recommendedFollowUpMonths: appointment.recommendedFollowUpMonths, professional: professional
            )
            copy.statusRawValue = appointment.statusRawValue
            copy.createdAt = appointment.createdAt
            destination.insert(copy)
        }

        // MARK: LensPair (depende de LensInventoryItem)

        var pairsByID: [UUID: LensPair] = [:]
        for pair in try destination.fetch(FetchDescriptor<LensPair>()) {
            pairsByID[pair.id] = pair
        }
        for pair in try source.fetch(FetchDescriptor<LensPair>()) where pairsByID[pair.id] == nil {
            let inventoryItem = pair.inventoryItem.flatMap { inventoryItemsByID[$0.id] }
            let copy = LensPair(
                id: pair.id, name: pair.name, sequenceNumber: pair.sequenceNumber, startDate: pair.startDate,
                maximumUses: pair.maximumUses, trackingMode: pair.trackingMode, side: pair.side, inventoryItem: inventoryItem
            )
            copy.endDate = pair.endDate
            copy.statusRawValue = pair.statusRawValue
            copy.discardReason = pair.discardReason
            copy.notes = pair.notes
            copy.deletedAt = pair.deletedAt
            copy.createdAt = pair.createdAt
            destination.insert(copy)
            pairsByID[pair.id] = copy
            summary.pairsCopied += 1
        }

        // MARK: Dependem de LensPair

        let existingUsageIDs = Set(try destination.fetch(FetchDescriptor<LensUsage>()).map(\.id))
        for usage in try source.fetch(FetchDescriptor<LensUsage>()) where !existingUsageIDs.contains(usage.id) {
            let pair = usage.lensPair.flatMap { pairsByID[$0.id] }
            destination.insert(LensUsage(id: usage.id, date: usage.date, side: usage.side, notes: usage.notes, lensPair: pair))
            summary.usagesCopied += 1
        }

        let existingSessionIDs = Set(try destination.fetch(FetchDescriptor<WearSession>()).map(\.id))
        for session in try source.fetch(FetchDescriptor<WearSession>()) where !existingSessionIDs.contains(session.id) {
            let pair = session.lensPair.flatMap { pairsByID[$0.id] }
            let copy = WearSession(id: session.id, startedAt: session.startedAt, lensPair: pair)
            copy.endedAt = session.endedAt
            copy.statusRawValue = session.statusRawValue
            copy.createdAt = session.createdAt
            destination.insert(copy)
            summary.wearSessionsCopied += 1
        }

        // MARK: HistoryEvent (lensPairID é um UUID solto, não uma relação — não precisa de mapa)

        let existingEventIDs = Set(try destination.fetch(FetchDescriptor<HistoryEvent>()).map(\.id))
        for event in try source.fetch(FetchDescriptor<HistoryEvent>()) where !existingEventIDs.contains(event.id) {
            let copy = HistoryEvent(
                id: event.id, eventType: event.eventType, eventDate: event.eventDate, lensPairID: event.lensPairID,
                lensPairName: event.lensPairName, side: event.side, descriptionText: event.descriptionText
            )
            copy.createdAt = event.createdAt
            destination.insert(copy)
        }

        do {
            try destination.save()
        } catch {
            throw MigrationError.persistenceFailed(error.localizedDescription)
        }

        return summary
    }
}
