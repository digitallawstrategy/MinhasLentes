import Foundation
import UserNotifications
import UIKit

/// Gerencia as notificações locais de limpeza do estojo. Usa exclusivamente `UserNotifications`
/// (sem servidor, push remoto ou serviço externo), portanto funciona mesmo com o aplicativo
/// fechado ou o aparelho bloqueado.
///
/// Identificadores são estáveis e específicos por finalidade — reais (`advanceIdentifier`,
/// `deadlineIdentifier`) e, apenas em builds DEBUG, de teste (`testOneMinuteIdentifier`,
/// `testTwoMinuteIdentifier`) — para que cancelamentos nunca se misturem entre si.
@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    nonisolated static let advanceIdentifier = "estojo.aviso-antecipado"
    nonisolated static let deadlineIdentifier = "estojo.prazo"
    nonisolated static let wearingReminderIdentifier = "lentes.remover-lembrete"

    nonisolated static let case15DayIdentifier = "estojo.substituicao.aviso-15dias"
    nonisolated static let case7DayIdentifier = "estojo.substituicao.aviso-7dias"
    nonisolated static let caseDueIdentifier = "estojo.substituicao.dia-recomendado"
    nonisolated static let caseOverdueRepeatIdentifier = "estojo.substituicao.lembrete-periodico"

    #if DEBUG
    static let testOneMinuteIdentifier = "dev.teste.aviso-1min"
    static let testTwoMinuteIdentifier = "dev.teste.aviso-2min"
    #endif

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    enum NotificationError: LocalizedError {
        case authorizationDenied
        case schedulingFailed(String)
        case verificationFailed(missing: Set<String>)

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "As notificações estão desativadas. Ative-as nos Ajustes do iPhone para receber os lembretes."
            case .schedulingFailed(let detail):
                return "Não foi possível agendar a notificação. \(detail)"
            case .verificationFailed(let missing):
                return "O agendamento não pôde ser confirmado junto ao sistema (\(missing.count) notificação(ões) ausente(s))."
            }
        }
    }

    /// Situação atual da autorização de notificações concedida pelo usuário no iOS.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Solicita autorização para alertas, sons e badges. Deve ser chamado depois que o usuário
    /// já viu a explicação em tela sobre o motivo das notificações. O resultado booleano já
    /// comunica claramente ao chamador se a permissão foi concedida — não há falha oculta.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Todas as notificações atualmente pendentes do aplicativo (reais e, em DEBUG, de teste).
    /// Consulta diretamente `UNUserNotificationCenter`, refletindo o estado real do sistema.
    func pendingNotifications() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    /// Cancela somente as notificações REAIS do ciclo de limpeza anterior — nunca as de teste.
    /// Em seguida consulta a fila real do sistema, para confirmar que o cancelamento já foi
    /// aplicado antes de prosseguir com o reagendamento.
    func cancelCaseCleaningNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.advanceIdentifier, Self.deadlineIdentifier])
        _ = await center.pendingNotificationRequests()
    }

    /// Agenda o aviso antecipado e o aviso no prazo com base na data da última limpeza e nas
    /// preferências salvas em `AppSettings`. Ao final, consulta `pendingNotificationRequests()`
    /// para confirmar que exatamente as notificações esperadas foram aceitas pelo sistema —
    /// se alguma estiver ausente, lança `NotificationError.verificationFailed`.
    @discardableResult
    func scheduleCaseCleaningNotifications(lastCleaningDate: Date, settings: AppSettings) async throws -> [UNNotificationRequest] {
        guard await authorizationStatus() == .authorized else {
            throw NotificationError.authorizationDenied
        }

        let deadlineDate = LensStatisticsService.nextCleaningDate(
            lastCleaningDate: lastCleaningDate,
            intervalDays: settings.cleaningIntervalDays
        )
        let advanceDate = LensStatisticsService.advanceReminderDate(
            lastCleaningDate: lastCleaningDate,
            intervalDays: settings.cleaningIntervalDays,
            advanceDays: settings.advanceReminderDays
        )

        var expectedIdentifiers: Set<String> = []

        if settings.advanceReminderEnabled, advanceDate > Date() {
            try await schedule(
                identifier: Self.advanceIdentifier,
                title: "Limpeza do estojo se aproximando",
                body: "Faltam \(settings.advanceReminderDays) dias para a limpeza periódica do estojo das lentes.",
                fireDate: advanceDate,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(Self.advanceIdentifier)
        }

        if settings.deadlineReminderEnabled, deadlineDate > Date() {
            try await schedule(
                identifier: Self.deadlineIdentifier,
                title: "Hora de limpar o estojo",
                body: "Hoje completa \(settings.cleaningIntervalDays) dias desde a última limpeza registrada.",
                fireDate: deadlineDate,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(Self.deadlineIdentifier)
        }

        let pending = await pendingNotifications()
        let pendingIdentifiers = Set(pending.map(\.identifier))
        let missing = expectedIdentifiers.subtracting(pendingIdentifiers)
        guard missing.isEmpty else {
            throw NotificationError.verificationFailed(missing: missing)
        }

        return pending.filter { expectedIdentifiers.contains($0.identifier) }
    }

    private func schedule(
        identifier: String,
        title: String,
        body: String,
        fireDate: Date,
        hour: Int,
        minute: Int,
        settings: AppSettings
    ) async throws {
        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = hour
        components.minute = minute
        components.second = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if settings.soundEnabled {
            content.sound = .default
        }
        if settings.badgeEnabled {
            content.badge = 1
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }

    // MARK: - Substituição do estojo (ciclo de vida do LensCase)

    /// Cancela apenas as notificações REAIS de substituição do estojo — os quatro identificadores
    /// (15 dias antes, 7 dias antes, no dia, e o lembrete periódico após o prazo).
    func cancelLensCaseNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.case15DayIdentifier, Self.case7DayIdentifier, Self.caseDueIdentifier, Self.caseOverdueRepeatIdentifier,
        ])
        _ = await center.pendingNotificationRequests()
    }

    /// Agenda os avisos de substituição do estojo (15 dias antes, 7 dias antes e no dia
    /// recomendado) a partir do início do ciclo atual. O lembrete periódico pós-prazo não é
    /// agendado aqui — como o prazo pode estar meses no futuro, ele só é agendado quando o prazo
    /// já tiver passado de fato, por `refreshOverdueCaseReminder`, chamado sempre que o app abre.
    ///
    /// Linguagem sempre não-alarmista, mesmo no aviso do dia: nunca "venceu"/"atrasado".
    @discardableResult
    func scheduleLensCaseNotifications(startDate: Date, intervalDays: Int, settings: AppSettings) async throws -> [UNNotificationRequest] {
        guard await authorizationStatus() == .authorized else {
            throw NotificationError.authorizationDenied
        }
        guard settings.caseReminderEnabled else { return [] }

        let dueDate = LensStatisticsService.nextCaseReplacementDate(startDate: startDate, intervalDays: intervalDays)
        let calendar = Calendar.current
        let day15 = calendar.date(byAdding: .day, value: -15, to: dueDate) ?? dueDate
        let day7 = calendar.date(byAdding: .day, value: -7, to: dueDate) ?? dueDate

        var expectedIdentifiers: Set<String> = []

        if day15 > Date() {
            try await schedule(
                identifier: Self.case15DayIdentifier,
                title: "Estojo de lentes",
                body: "Está se aproximando o momento recomendado para substituir o estojo.",
                fireDate: day15,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(Self.case15DayIdentifier)
        }

        if day7 > Date() {
            try await schedule(
                identifier: Self.case7DayIdentifier,
                title: "Estojo de lentes",
                body: "Faltam cerca de 7 dias para o momento recomendado de substituir o estojo.",
                fireDate: day7,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(Self.case7DayIdentifier)
        }

        if dueDate > Date() {
            try await schedule(
                identifier: Self.caseDueIdentifier,
                title: "Estojo de lentes",
                body: "Hoje é o dia recomendado para substituir o estojo, conforme o intervalo configurado.",
                fireDate: dueDate,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(Self.caseDueIdentifier)
        }

        let pending = await pendingNotifications()
        let pendingIdentifiers = Set(pending.map(\.identifier))
        let missing = expectedIdentifiers.subtracting(pendingIdentifiers)
        guard missing.isEmpty else {
            throw NotificationError.verificationFailed(missing: missing)
        }
        return pending.filter { expectedIdentifiers.contains($0.identifier) }
    }

    /// Idempotente — seguro chamar toda vez que o app abre. Se o ciclo atual do estojo já
    /// passou do prazo recomendado e ainda não há um lembrete periódico pendente, agenda um,
    /// repetindo a cada `caseOverdueReminderIntervalDays` dias a partir de agora. Não faz nada
    /// se o estojo não estiver atrasado, se os avisos estiverem desligados, ou se um lembrete
    /// já estiver agendado.
    func refreshOverdueCaseReminder(dueDate: Date, settings: AppSettings) async {
        guard settings.caseReminderEnabled, dueDate <= Date() else { return }
        guard await authorizationStatus() == .authorized else { return }

        let pending = await pendingNotifications()
        guard !pending.contains(where: { $0.identifier == Self.caseOverdueRepeatIdentifier }) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Estojo de lentes"
        content.body = "Ainda não há registro de substituição do estojo. Considere substituí-lo quando for conveniente."
        if settings.soundEnabled { content.sound = .default }
        if settings.badgeEnabled { content.badge = 1 }

        let intervalSeconds = TimeInterval(max(1, settings.caseOverdueReminderIntervalDays) * 86400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: intervalSeconds, repeats: true)
        let request = UNNotificationRequest(identifier: Self.caseOverdueRepeatIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Lembrete de remoção ("Estou usando as lentes")

    /// Agenda o lembrete "Hora de remover as lentes?" para o fim de uma sessão de uso. Ao
    /// contrário do ciclo de limpeza, este lembrete é único (não repete) e é cancelado
    /// automaticamente se a sessão for encerrada manualmente antes do horário.
    func scheduleWearingReminder(at date: Date, settings: AppSettings) async throws {
        guard await authorizationStatus() == .authorized else {
            throw NotificationError.authorizationDenied
        }
        let content = UNMutableNotificationContent()
        content.title = "Hora de remover as lentes?"
        content.body = "Você ativou \"Estou usando as lentes\" há um bom tempo. Considere removê-las para descansar os olhos."
        if settings.soundEnabled {
            content.sound = .default
        }
        if settings.badgeEnabled {
            content.badge = 1
        }
        let interval = max(60, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.wearingReminderIdentifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }

    func cancelWearingReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.wearingReminderIdentifier])
    }

    /// Abre a tela de Ajustes do aplicativo no iOS, usada quando as notificações do sistema
    /// estão desativadas.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    #if DEBUG
    // MARK: - Ferramentas de desenvolvimento (compiladas apenas em builds DEBUG)
    //
    // Usam identificadores próprios (`testOneMinuteIdentifier`/`testTwoMinuteIdentifier`),
    // nunca os identificadores reais do ciclo de limpeza. Não tocam em `CaseCleaning` nem em
    // `AppSettings` e o cancelamento de teste nunca remove as notificações reais.

    private func scheduleTestNotification(afterSeconds seconds: TimeInterval, identifier: String, label: String) async throws {
        guard await authorizationStatus() == .authorized else {
            throw NotificationError.authorizationDenied
        }
        let content = UNMutableNotificationContent()
        content.title = "Notificação de teste"
        content.body = "\(label) — disparada \(Int(seconds))s após o agendamento."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }

    /// Agenda uma única notificação de teste, disparada 60 segundos após o agendamento.
    func scheduleSingleTestNotification() async throws {
        try await scheduleTestNotification(afterSeconds: 60, identifier: Self.testOneMinuteIdentifier, label: "Teste em 1 minuto")
    }

    /// Agenda duas notificações de teste, disparadas em 60 e 120 segundos.
    func scheduleTwoTestNotifications() async throws {
        try await scheduleTestNotification(afterSeconds: 60, identifier: Self.testOneMinuteIdentifier, label: "Teste em 1 minuto")
        try await scheduleTestNotification(afterSeconds: 120, identifier: Self.testTwoMinuteIdentifier, label: "Teste em 2 minutos")
    }

    /// Cancela apenas as notificações de teste — nunca as reais do ciclo de limpeza.
    func cancelTestNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.testOneMinuteIdentifier, Self.testTwoMinuteIdentifier])
        _ = await center.pendingNotificationRequests()
    }
    #endif
}

// MARK: - Deep link ao tocar numa notificação

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Mostra a notificação normalmente mesmo com o app aberto — sem isso, o sistema some
    /// silenciosamente com o banner em primeiro plano.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// Leva o usuário para a aba certa quando ele toca numa notificação: Estojo para os
    /// avisos de limpeza, Início para o lembrete de remoção das lentes.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        await MainActor.run {
            switch identifier {
            case Self.advanceIdentifier, Self.deadlineIdentifier,
                 Self.case15DayIdentifier, Self.case7DayIdentifier, Self.caseDueIdentifier, Self.caseOverdueRepeatIdentifier:
                AppRouter.shared.openEstojo()
            case Self.wearingReminderIdentifier:
                AppRouter.shared.openHome()
            default:
                break
            }
        }
    }
}
