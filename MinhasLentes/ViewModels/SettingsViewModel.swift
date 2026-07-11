import Foundation
import Observation
import SwiftData
import UserNotifications

/// Estado e ações da tela Configurações: preferências, notificações, backup/exportação e
/// gerenciamento de dados. Toda falha é exposta via `presentedError` — nenhuma operação
/// crítica (salvar, agendar notificação, exportar, importar, apagar dados) falha em silêncio.
@MainActor
@Observable
final class SettingsViewModel {
    var showEraseConfirmation = false
    var showTrackingModeChangeWarning = false
    var pendingTrackingMode: TrackingMode?
    var exportedFileURL: URL?
    var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var presentedError: IdentifiableError?

    // MARK: - Backup/restauração

    var showImportModeChoice = false
    var importReport: BackupService.ImportReport?
    private var pendingImportURL: URL?

    #if DEBUG
    var devToolsMessage: String?
    var pendingNotificationsSummary: String?
    #endif

    func refreshAuthorizationStatus() async {
        notificationAuthorizationStatus = await NotificationManager.shared.authorizationStatus()
    }

    func requestNotificationAuthorization() async {
        _ = await NotificationManager.shared.requestAuthorization()
        await refreshAuthorizationStatus()
    }

    func openSystemSettings() {
        NotificationManager.shared.openSystemSettings()
    }

    /// Deve ser chamado após qualquer alteração nas preferências de limpeza/notificação para
    /// reagendar o ciclo com os novos valores (cancelando o anterior e confirmando o novo).
    func rescheduleNotifications(settings: AppSettings, context: ModelContext) async {
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar a preferência. \(error.localizedDescription)")
            return
        }
        do {
            guard let last = try CaseCleaningService.lastCleaning(context: context) else { return }
            await NotificationManager.shared.cancelCaseCleaningNotifications()
            try await NotificationManager.shared.scheduleCaseCleaningNotifications(lastCleaningDate: last.cleaningDate, settings: settings)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível reagendar as notificações. \(error.localizedDescription)")
        }
    }

    /// Deve ser chamado após alterar `caseReminderEnabled` ou `caseOverdueReminderIntervalDays`,
    /// para que a mudança valha imediatamente para o ciclo ativo do estojo (se houver), em vez
    /// de só na próxima vez que o app abrir.
    func rescheduleLensCaseNotifications(settings: AppSettings, context: ModelContext) async {
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar a preferência. \(error.localizedDescription)")
            return
        }
        guard let activeCase = try? LensCaseService.activeCase(context: context) else { return }
        await NotificationManager.shared.cancelLensCaseNotifications()
        do {
            try await NotificationManager.shared.scheduleLensCaseNotifications(
                startDate: activeCase.startDate, intervalDays: activeCase.intervalDays, settings: settings
            )
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível reagendar as notificações do estojo. \(error.localizedDescription)")
            return
        }
        await NotificationManager.shared.refreshOverdueCaseReminder(
            dueDate: activeCase.nextRecommendedReplacementDate, settings: settings
        )
    }

    /// Deve ser chamado após alterar `solutionReminderEnabled` ou
    /// `solutionOverdueReminderIntervalDays`, para que a mudança valha imediatamente para o
    /// frasco ativo de solução (se houver).
    func rescheduleCleaningSolutionNotifications(settings: AppSettings, context: ModelContext) async {
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar a preferência. \(error.localizedDescription)")
            return
        }
        guard let activeSolution = try? CleaningSolutionService.activeSolution(context: context) else { return }
        await NotificationManager.shared.cancelCleaningSolutionNotifications()
        do {
            try await NotificationManager.shared.scheduleCleaningSolutionNotifications(discardDate: activeSolution.discardDate, settings: settings)
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível reagendar as notificações da solução. \(error.localizedDescription)")
            return
        }
        await NotificationManager.shared.refreshOverdueSolutionReminder(discardDate: activeSolution.discardDate, settings: settings)
    }

    /// Deve ser chamado após alterar `inventoryReminderEnabled`. Como pode haver vários itens
    /// de estoque simultaneamente (diferente de estojo/solução), reagenda item por item.
    func rescheduleLensInventoryNotifications(settings: AppSettings, context: ModelContext) async {
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar a preferência. \(error.localizedDescription)")
            return
        }
        guard let items = try? LensInventoryService.availableItems(context: context) else { return }
        for item in items {
            await NotificationManager.shared.cancelLensInventoryNotifications(for: item.id)
            do {
                try await NotificationManager.shared.scheduleLensInventoryNotifications(for: item, settings: settings)
            } catch {
                presentedError = IdentifiableError(message: "Não foi possível reagendar as notificações do estoque. \(error.localizedDescription)")
            }
        }
    }

    /// Deve ser chamado após alterar `appointmentReminderEnabled`. Como pode haver várias
    /// consultas agendadas simultaneamente, reagenda uma a uma.
    func rescheduleEyeAppointmentNotifications(settings: AppSettings, context: ModelContext) async {
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar a preferência. \(error.localizedDescription)")
            return
        }
        guard let appointments = try? EyeAppointmentService.allAppointments(context: context) else { return }
        for appointment in appointments where appointment.status == .scheduled {
            await NotificationManager.shared.cancelEyeAppointmentNotifications(for: appointment.id)
            do {
                try await NotificationManager.shared.scheduleEyeAppointmentNotifications(
                    for: appointment, professionalName: appointment.professional?.name, settings: settings
                )
            } catch {
                presentedError = IdentifiableError(message: "Não foi possível reagendar as notificações de consulta. \(error.localizedDescription)")
            }
        }
    }

    func requestTrackingModeChange(to newMode: TrackingMode, current: TrackingMode) {
        guard newMode != current else { return }
        pendingTrackingMode = newMode
        showTrackingModeChangeWarning = true
    }

    func confirmTrackingModeChange(settings: AppSettings, context: ModelContext) {
        guard let newMode = pendingTrackingMode else { return }
        settings.trackingMode = newMode
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível salvar o modo de controle. \(error.localizedDescription)")
        }
        pendingTrackingMode = nil
        showTrackingModeChangeWarning = false
    }

    func cancelTrackingModeChange() {
        pendingTrackingMode = nil
        showTrackingModeChangeWarning = false
    }

    /// Apaga todos os dados de forma "tudo ou nada": se qualquer etapa falhar, a operação é
    /// desfeita por completo (`context.rollback()`) e nenhum dado é perdido.
    func eraseAllData(context: ModelContext) async {
        let inventoryItemIDs = (try? LensInventoryService.allItems(context: context).map(\.id)) ?? []
        let appointmentIDs = (try? EyeAppointmentService.allAppointments(context: context).map(\.id)) ?? []
        do {
            for usage in try context.fetch(FetchDescriptor<LensUsage>()) { context.delete(usage) }
            for pair in try context.fetch(FetchDescriptor<LensPair>()) { context.delete(pair) }
            for cleaning in try context.fetch(FetchDescriptor<CaseCleaning>()) { context.delete(cleaning) }
            for event in try context.fetch(FetchDescriptor<HistoryEvent>()) { context.delete(event) }
            for settings in try context.fetch(FetchDescriptor<AppSettings>()) { context.delete(settings) }
            for lensCase in try context.fetch(FetchDescriptor<LensCase>()) { context.delete(lensCase) }
            for log in try context.fetch(FetchDescriptor<RoutineCareLog>()) { context.delete(log) }
            for solution in try context.fetch(FetchDescriptor<CleaningSolution>()) { context.delete(solution) }
            for item in try context.fetch(FetchDescriptor<LensInventoryItem>()) { context.delete(item) }
            for appointment in try context.fetch(FetchDescriptor<EyeAppointment>()) { context.delete(appointment) }
            for professional in try context.fetch(FetchDescriptor<EyeCareProfessional>()) { context.delete(professional) }
            for session in try context.fetch(FetchDescriptor<WearSession>()) { context.delete(session) }
            try context.save()
        } catch {
            context.rollback()
            presentedError = IdentifiableError(message: "Não foi possível apagar os dados; nenhuma informação foi perdida. \(error.localizedDescription)")
            return
        }
        await NotificationManager.shared.cancelCaseCleaningNotifications()
        await NotificationManager.shared.cancelLensCaseNotifications()
        await NotificationManager.shared.cancelCleaningSolutionNotifications()
        for itemID in inventoryItemIDs {
            await NotificationManager.shared.cancelLensInventoryNotifications(for: itemID)
        }
        for appointmentID in appointmentIDs {
            await NotificationManager.shared.cancelEyeAppointmentNotifications(for: appointmentID)
        }
        NotificationManager.shared.cancelWearingExcessiveNotifications()
        await LiveActivityService.endWearingSession()
        #if DEBUG
        await NotificationManager.shared.cancelTestNotifications()
        #endif
    }

    func restoreDefaults(settings: AppSettings, context: ModelContext) {
        settings.restoreDefaults()
        do {
            try context.save()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível restaurar as configurações padrão. \(error.localizedDescription)")
        }
    }

    func exportCSV(pairs: [LensPair], cleanings: [CaseCleaning]) {
        do {
            exportedFileURL = try CSVExporter.export(pairs: pairs, cleanings: cleanings)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func exportPDF(pairs: [LensPair], cleanings: [CaseCleaning]) {
        do {
            exportedFileURL = try PDFExporter.export(pairs: pairs, cleanings: cleanings)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func exportBackup(context: ModelContext) {
        do {
            exportedFileURL = try BackupService.exportJSON(context: context)
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    // MARK: - Importação de backup

    /// Chamado com o resultado do `.fileImporter`. Valida o arquivo imediatamente — antes de
    /// qualquer alteração no armazenamento — e, se for válido, pede ao usuário para escolher
    /// entre substituir ou mesclar os dados.
    func handlePickedBackupFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                _ = try BackupService.validate(url: url)
                pendingImportURL = url
                showImportModeChoice = true
            } catch {
                presentedError = IdentifiableError(message: error.localizedDescription)
            }
        case .failure(let error):
            presentedError = IdentifiableError(message: "Não foi possível abrir o arquivo selecionado. \(error.localizedDescription)")
        }
    }

    func performImport(mode: BackupService.ImportMode, context: ModelContext) {
        guard let url = pendingImportURL else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            importReport = try BackupService.importBackup(from: url, mode: mode, context: context)
            HapticsService.success()
            // Os dados voltam com um único context.save() — sem isso, os avisos de
            // estojo/solução/estoque/consultas/sessão de uso restaurados nunca seriam
            // reagendados: eles só existem quando algo explicitamente os agenda.
            if let settings = try? AppSettingsStore.currentSettings(context: context) {
                Task { await NotificationReconciliationService.rebuildAll(context: context, settings: settings) }
            }
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
        pendingImportURL = nil
        showImportModeChoice = false
    }

    func cancelImport() {
        pendingImportURL = nil
        showImportModeChoice = false
    }

    #if DEBUG
    // MARK: - Ferramentas de desenvolvimento (apenas builds DEBUG)

    func scheduleSingleTestNotification() async {
        do {
            try await NotificationManager.shared.scheduleSingleTestNotification()
            devToolsMessage = "Notificação de teste agendada para daqui a 1 minuto."
        } catch {
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func scheduleTwoTestNotifications() async {
        do {
            try await NotificationManager.shared.scheduleTwoTestNotifications()
            devToolsMessage = "Notificações de teste agendadas para 1 e 2 minutos."
        } catch {
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }

    func cancelTestNotifications() async {
        await NotificationManager.shared.cancelTestNotifications()
        devToolsMessage = "Notificações de teste canceladas."
    }

    func listPendingNotifications() async {
        let pending = await NotificationManager.shared.pendingNotifications()
        if pending.isEmpty {
            pendingNotificationsSummary = "Nenhuma notificação pendente."
            return
        }
        let lines = pending.map { request -> String in
            if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger,
               let date = calendarTrigger.nextTriggerDate() {
                return "• \(request.identifier) — \(DateFormatting.shortWithTime.string(from: date))"
            }
            if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                return "• \(request.identifier) — em ~\(Int(intervalTrigger.timeInterval))s"
            }
            return "• \(request.identifier)"
        }
        pendingNotificationsSummary = lines.joined(separator: "\n")
    }

    func listLiveActivities() {
        devToolsMessage = LiveActivityService.debugActivitiesSummary()
    }

    func endAllLiveActivities() async {
        await LiveActivityService.endAllActivitiesForDebugging()
        devToolsMessage = "Todas as Live Activities foram encerradas."
    }
    #endif
}
