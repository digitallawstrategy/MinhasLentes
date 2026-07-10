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
        do {
            for usage in try context.fetch(FetchDescriptor<LensUsage>()) { context.delete(usage) }
            for pair in try context.fetch(FetchDescriptor<LensPair>()) { context.delete(pair) }
            for cleaning in try context.fetch(FetchDescriptor<CaseCleaning>()) { context.delete(cleaning) }
            for event in try context.fetch(FetchDescriptor<HistoryEvent>()) { context.delete(event) }
            for settings in try context.fetch(FetchDescriptor<AppSettings>()) { context.delete(settings) }
            try context.save()
        } catch {
            context.rollback()
            presentedError = IdentifiableError(message: "Não foi possível apagar os dados; nenhuma informação foi perdida. \(error.localizedDescription)")
            return
        }
        await NotificationManager.shared.cancelCaseCleaningNotifications()
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
    #endif
}
