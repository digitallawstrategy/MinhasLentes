import Foundation
import UserNotifications
import UIKit
import SwiftData

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
    nonisolated static let wearingFirstIdentifier = "lentes.excessivo.aviso1"
    nonisolated static let wearingSecondIdentifier = "lentes.excessivo.aviso2"
    nonisolated static let wearingThirdIdentifier = "lentes.excessivo.aviso3"
    nonisolated static let wearingRepeatIdentifier = "lentes.excessivo.repetitivo"
    nonisolated static let wearingCategoryIdentifier = "lentes.excessivo.categoria"
    nonisolated static let wearingEndSessionActionIdentifier = "lentes.excessivo.retirei-agora"

    nonisolated static let case15DayIdentifier = "estojo.substituicao.aviso-15dias"
    nonisolated static let case7DayIdentifier = "estojo.substituicao.aviso-7dias"
    nonisolated static let caseDueIdentifier = "estojo.substituicao.dia-recomendado"
    nonisolated static let caseOverdueRepeatIdentifier = "estojo.substituicao.lembrete-periodico"

    nonisolated static let solution30DayIdentifier = "solucao.aviso-30dias"
    nonisolated static let solution7DayIdentifier = "solucao.aviso-7dias"
    nonisolated static let solutionDueIdentifier = "solucao.dia-descarte"
    nonisolated static let solutionOverdueRepeatIdentifier = "solucao.lembrete-periodico"

    #if DEBUG
    static let testOneMinuteIdentifier = "dev.teste.aviso-1min"
    static let testTwoMinuteIdentifier = "dev.teste.aviso-2min"
    #endif

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        let endSessionAction = UNNotificationAction(
            identifier: Self.wearingEndSessionActionIdentifier,
            title: "Retirei agora",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.wearingCategoryIdentifier,
            actions: [endSessionAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
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

    // MARK: - Validade da solução de limpeza (ciclo de vida do CleaningSolution)

    /// Cancela apenas as notificações REAIS de validade da solução — os quatro identificadores
    /// (30 dias antes, 7 dias antes, no dia, e o lembrete periódico após o prazo).
    func cancelCleaningSolutionNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.solution30DayIdentifier, Self.solution7DayIdentifier, Self.solutionDueIdentifier, Self.solutionOverdueRepeatIdentifier,
        ])
        _ = await center.pendingNotificationRequests()
    }

    /// Agenda os avisos de validade da solução de limpeza (30 dias antes, 7 dias antes e no dia
    /// de descarte recomendado) a partir da data de descarte já calculada
    /// (`LensStatisticsService.solutionDiscardDate`). O lembrete periódico pós-prazo segue o
    /// mesmo raciocínio do estojo: só é agendado quando o prazo já passou de fato, por
    /// `refreshOverdueSolutionReminder`.
    @discardableResult
    func scheduleCleaningSolutionNotifications(discardDate: Date, settings: AppSettings) async throws -> [UNNotificationRequest] {
        guard await authorizationStatus() == .authorized else {
            throw NotificationError.authorizationDenied
        }
        guard settings.solutionReminderEnabled else { return [] }

        let calendar = Calendar.current
        let day30 = calendar.date(byAdding: .day, value: -30, to: discardDate) ?? discardDate
        let day7 = calendar.date(byAdding: .day, value: -7, to: discardDate) ?? discardDate

        var expectedIdentifiers: Set<String> = []

        if day30 > Date() {
            try await schedule(
                identifier: Self.solution30DayIdentifier,
                title: "Solução de limpeza",
                body: "Uma das suas soluções de limpeza está se aproximando da validade recomendada após aberta.",
                fireDate: day30,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(Self.solution30DayIdentifier)
        }

        if day7 > Date() {
            try await schedule(
                identifier: Self.solution7DayIdentifier,
                title: "Solução de limpeza",
                body: "Faltam poucos dias para a validade recomendada da solução de limpeza aberta.",
                fireDate: day7,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(Self.solution7DayIdentifier)
        }

        if discardDate > Date() {
            try await schedule(
                identifier: Self.solutionDueIdentifier,
                title: "Solução de limpeza",
                body: "Hoje é a data de validade recomendada da solução de limpeza aberta, considerando o prazo indicado pelo fabricante.",
                fireDate: discardDate,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(Self.solutionDueIdentifier)
        }

        let pending = await pendingNotifications()
        let pendingIdentifiers = Set(pending.map(\.identifier))
        let missing = expectedIdentifiers.subtracting(pendingIdentifiers)
        guard missing.isEmpty else {
            throw NotificationError.verificationFailed(missing: missing)
        }
        return pending.filter { expectedIdentifiers.contains($0.identifier) }
    }

    /// Idempotente — seguro chamar toda vez que o app abre. Mesmo raciocínio de
    /// `refreshOverdueCaseReminder`, aplicado à solução de limpeza ativa.
    func refreshOverdueSolutionReminder(discardDate: Date, settings: AppSettings) async {
        guard settings.solutionReminderEnabled, discardDate <= Date() else { return }
        guard await authorizationStatus() == .authorized else { return }

        let pending = await pendingNotifications()
        guard !pending.contains(where: { $0.identifier == Self.solutionOverdueRepeatIdentifier }) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Solução de limpeza"
        content.body = "Ainda não há registro de troca da solução de limpeza. Considere substituí-la quando for conveniente."
        if settings.soundEnabled { content.sound = .default }
        if settings.badgeEnabled { content.badge = 1 }

        let intervalSeconds = TimeInterval(max(1, settings.solutionOverdueReminderIntervalDays) * 86400)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: intervalSeconds, repeats: true)
        let request = UNNotificationRequest(identifier: Self.solutionOverdueRepeatIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Validade de itens em estoque (LensInventoryItem)
    //
    // Diferente do estojo e da solução, vários itens de estoque podem existir ao mesmo tempo —
    // por isso os identificadores aqui são por item (`estoque.<uuid>.<marco>`), não fixos como
    // `case15DayIdentifier`. Sem lembrete periódico pós-validade: um item vencido e não usado é
    // um aviso único, não uma pendência recorrente como trocar o estojo ou a solução.

    private func inventoryIdentifiers(for itemID: UUID) -> [String] {
        ["60dias", "30dias", "7dias", "dia"].map { "estoque.\(itemID.uuidString).\($0)" }
    }

    func cancelLensInventoryNotifications(for itemID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: inventoryIdentifiers(for: itemID))
        _ = await center.pendingNotificationRequests()
    }

    @discardableResult
    func scheduleLensInventoryNotifications(for item: LensInventoryItem, settings: AppSettings) async throws -> [UNNotificationRequest] {
        guard await authorizationStatus() == .authorized else {
            throw NotificationError.authorizationDenied
        }
        guard settings.inventoryReminderEnabled, let expiryDate = item.expiryDate else { return [] }

        let calendar = Calendar.current
        let identifiers = inventoryIdentifiers(for: item.id)
        let offsets = [60, 30, 7, 0]
        var expectedIdentifiers: Set<String> = []

        let label = "\(item.brand) \(item.model)".trimmingCharacters(in: .whitespaces)
        for (offset, identifier) in zip(offsets, identifiers) {
            let fireDate = calendar.date(byAdding: .day, value: -offset, to: expiryDate) ?? expiryDate
            guard fireDate > Date() else { continue }
            let body = offset == 0
                ? "Hoje é a validade indicada para a lente \(label) guardada no estoque."
                : "Faltam cerca de \(offset) dias para a validade da lente \(label) guardada no estoque."
            try await schedule(
                identifier: identifier,
                title: "Estoque de lentes",
                body: body,
                fireDate: fireDate,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(identifier)
        }

        let pending = await pendingNotifications()
        let pendingIdentifiers = Set(pending.map(\.identifier))
        let missing = expectedIdentifiers.subtracting(pendingIdentifiers)
        guard missing.isEmpty else {
            throw NotificationError.verificationFailed(missing: missing)
        }
        return pending.filter { expectedIdentifiers.contains($0.identifier) }
    }

    // MARK: - Consultas (EyeAppointment)
    //
    // Como estoque, várias consultas podem estar agendadas ao mesmo tempo — identificadores por
    // consulta (`consulta.<uuid>.<marco>`). O aviso de 2 horas antes é o único que precisa do
    // horário exato da consulta, não do horário configurado em Ajustes.

    private func appointmentIdentifiers(for appointmentID: UUID) -> [String] {
        ["30dias", "7dias", "1dia", "2horas"].map { "consulta.\(appointmentID.uuidString).\($0)" }
    }

    func cancelEyeAppointmentNotifications(for appointmentID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: appointmentIdentifiers(for: appointmentID))
        _ = await center.pendingNotificationRequests()
    }

    @discardableResult
    func scheduleEyeAppointmentNotifications(
        for appointment: EyeAppointment,
        professionalName: String?,
        settings: AppSettings
    ) async throws -> [UNNotificationRequest] {
        guard await authorizationStatus() == .authorized else {
            throw NotificationError.authorizationDenied
        }
        guard settings.appointmentReminderEnabled, appointment.status == .scheduled else { return [] }

        let calendar = Calendar.current
        let date = appointment.date
        let identifiers = appointmentIdentifiers(for: appointment.id)
        let label = professionalName.map { " com \($0)" } ?? ""
        var expectedIdentifiers: Set<String> = []

        let dayOffsets: [(days: Int, identifier: String, body: String)] = [
            (30, identifiers[0], "Faltam cerca de 30 dias para sua consulta\(label)."),
            (7, identifiers[1], "Faltam cerca de 7 dias para sua consulta\(label)."),
            (1, identifiers[2], "Sua consulta\(label) é amanhã."),
        ]
        for entry in dayOffsets {
            let fireDate = calendar.date(byAdding: .day, value: -entry.days, to: date) ?? date
            guard fireDate > Date() else { continue }
            try await schedule(
                identifier: entry.identifier,
                title: "Consulta oftalmológica",
                body: entry.body,
                fireDate: fireDate,
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
                settings: settings
            )
            expectedIdentifiers.insert(entry.identifier)
        }

        if let twoHoursBefore = calendar.date(byAdding: .hour, value: -2, to: date), twoHoursBefore > Date() {
            try await scheduleAtExactMoment(
                identifier: identifiers[3],
                title: "Consulta oftalmológica",
                body: "Sua consulta\(label) é daqui a 2 horas.",
                fireDate: twoHoursBefore,
                settings: settings
            )
            expectedIdentifiers.insert(identifiers[3])
        }

        let pending = await pendingNotifications()
        let pendingIdentifiers = Set(pending.map(\.identifier))
        let missing = expectedIdentifiers.subtracting(pendingIdentifiers)
        guard missing.isEmpty else {
            throw NotificationError.verificationFailed(missing: missing)
        }
        return pending.filter { expectedIdentifiers.contains($0.identifier) }
    }

    /// Como `schedule(identifier:title:body:fireDate:hour:minute:settings:)`, mas usa o
    /// horário exato de `fireDate` em vez do horário configurado em Ajustes — necessário para
    /// o aviso "2 horas antes", que é sensível ao horário real da consulta.
    private func scheduleAtExactMoment(identifier: String, title: String, body: String, fireDate: Date, settings: AppSettings) async throws {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if settings.soundEnabled { content.sound = .default }
        if settings.badgeEnabled { content.badge = 1 }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
    }

    // MARK: - Alertas progressivos de tempo de uso ("Estou usando as lentes")
    //
    // Três avisos fixos (limiar configurável, +1h, +2h) e, depois disso, um lembrete que se
    // repete a cada `wearingExcessiveRepeatIntervalHours` enquanto a sessão continuar ativa.
    // Todos usam `wearingCategoryIdentifier`, que dá ao usuário o botão "Retirei agora" direto
    // na notificação, sem precisar abrir o app.

    func cancelWearingExcessiveNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.wearingFirstIdentifier, Self.wearingSecondIdentifier, Self.wearingThirdIdentifier, Self.wearingRepeatIdentifier,
        ])
    }

    /// Agenda os três avisos fixos a partir de `wearingSince` — chamado tanto ao iniciar uma
    /// sessão quanto ao restaurá-la (nesse caso, `wearingSince` pode já estar horas no passado,
    /// e os avisos cujo horário já passou simplesmente não são agendados).
    @discardableResult
    func scheduleWearingExcessiveNotifications(wearingSince: Date, settings: AppSettings) async throws -> [UNNotificationRequest] {
        guard await authorizationStatus() == .authorized else {
            throw NotificationError.authorizationDenied
        }
        let thresholds: [(hours: Int, identifier: String)] = [
            (settings.wearingReminderHours, Self.wearingFirstIdentifier),
            (settings.wearingReminderHours + 1, Self.wearingSecondIdentifier),
            (settings.wearingReminderHours + 2, Self.wearingThirdIdentifier),
        ]
        var expectedIdentifiers: Set<String> = []
        for threshold in thresholds {
            let fireDate = wearingSince.addingTimeInterval(Double(threshold.hours) * 3600)
            guard fireDate > Date() else { continue }
            try await scheduleWearingAlert(identifier: threshold.identifier, fireDate: fireDate, settings: settings)
            expectedIdentifiers.insert(threshold.identifier)
        }
        let pending = await pendingNotifications()
        return pending.filter { expectedIdentifiers.contains($0.identifier) }
    }

    /// Idempotente — chamado sempre que o app abre e sempre que ele volta a ficar ativo (ver
    /// `ContentView`, tanto no `.task` inicial quanto na mudança de `scenePhase`), para pegar o
    /// caso do app nunca ter sido encerrado de fato durante toda a janela dos três avisos fixos.
    /// Se a sessão já passou do terceiro aviso e nenhum lembrete repetitivo estiver pendente,
    /// agenda um repetindo a cada `wearingExcessiveRepeatIntervalHours` a partir de agora —
    /// mesmo raciocínio do lembrete pós-prazo do estojo/solução, e pelo mesmo motivo: não dá
    /// para agendar de antemão uma repetição ancorada a um horário futuro incerto.
    func refreshWearingExcessiveRepeatReminder(wearingSince: Date, settings: AppSettings) async {
        let thirdThreshold = wearingSince.addingTimeInterval(Double(settings.wearingReminderHours + 2) * 3600)
        guard thirdThreshold <= Date() else { return }
        guard await authorizationStatus() == .authorized else { return }

        let pending = await pendingNotifications()
        guard !pending.contains(where: { $0.identifier == Self.wearingRepeatIdentifier }) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Você ainda está utilizando suas lentes?"
        content.body = "Considere removê-las para descansar os olhos."
        content.categoryIdentifier = Self.wearingCategoryIdentifier
        if settings.soundEnabled { content.sound = .default }
        if settings.badgeEnabled { content.badge = 1 }

        let intervalSeconds = TimeInterval(max(1, settings.wearingExcessiveRepeatIntervalHours) * 3600)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: intervalSeconds, repeats: true)
        let request = UNNotificationRequest(identifier: Self.wearingRepeatIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleWearingAlert(identifier: String, fireDate: Date, settings: AppSettings) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Você ainda está utilizando suas lentes?"
        content.body = "Considere removê-las para descansar os olhos."
        content.categoryIdentifier = Self.wearingCategoryIdentifier
        if settings.soundEnabled { content.sound = .default }
        if settings.badgeEnabled { content.badge = 1 }

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            throw NotificationError.schedulingFailed(error.localizedDescription)
        }
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
    /// avisos de limpeza, Lentes para os alertas de tempo de uso e estoque, Consultas para
    /// consultas. O botão "Retirei agora" (nos alertas de tempo de uso) encerra a sessão direto
    /// no banco, antes de qualquer coisa relacionada à UI — a ação usa `options: []`
    /// (não traz o app para primeiro plano), então o processo pode ser apenas acordado em
    /// segundo plano para rodar este handler, sem a árvore de Views chegar a existir. Depender
    /// só de `AppRouter.pendingEndWearingSession` nesse cenário nunca encerraria a sessão de
    /// verdade — por isso ela é encerrada aqui, e o roteamento de UI é só um complemento para
    /// quando o app já estiver (ou vier a ficar) em primeiro plano.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        let wearingIdentifiers: Set<String> = [
            Self.wearingFirstIdentifier, Self.wearingSecondIdentifier, Self.wearingThirdIdentifier, Self.wearingRepeatIdentifier,
        ]

        if actionIdentifier == Self.wearingEndSessionActionIdentifier {
            await Self.endWearingSessionDirectly()
            await MainActor.run {
                AppRouter.shared.pendingEndWearingSession = true
                AppRouter.shared.openHome()
            }
            return
        }

        await MainActor.run {
            switch identifier {
            case Self.advanceIdentifier, Self.deadlineIdentifier,
                 Self.case15DayIdentifier, Self.case7DayIdentifier, Self.caseDueIdentifier, Self.caseOverdueRepeatIdentifier:
                AppRouter.shared.openEstojo()
            case Self.solution30DayIdentifier, Self.solution7DayIdentifier, Self.solutionDueIdentifier, Self.solutionOverdueRepeatIdentifier:
                AppRouter.shared.openSolution()
            case let id where id.hasPrefix("estoque."):
                // Identificadores de estoque são por item (`estoque.<uuid>.<marco>`) — o
                // estoque fica um toque à frente, dentro da aba Lentes.
                AppRouter.shared.openLentes()
            case let id where id.hasPrefix("consulta."):
                // Identificadores de consulta são por consulta (`consulta.<uuid>.<marco>`).
                AppRouter.shared.openConsultas()
            case let id where wearingIdentifiers.contains(id):
                AppRouter.shared.openHome()
            default:
                break
            }
        }
    }

    /// Encerra a sessão de uso ativa direto no `ModelContext`, sem depender de nenhuma `View`
    /// ter aparecido — abre o `ModelContainer` compartilhado (`AppContainer`, o mesmo usado por
    /// `MinhasLentesApp`, nunca um segundo contêiner independente) e grava `endedAt`/`status`
    /// como `WearSessionService.endSession` faria. Melhor esforço: se o contêiner não puder ser
    /// aberto ou não houver sessão ativa, não há nada a fazer aqui — o caminho de UI
    /// (`pendingEndWearingSession`) ainda cobre o caso do app já estar em primeiro plano.
    private static func endWearingSessionDirectly() async {
        do {
            let container = try AppContainer.shared()
            let context = ModelContext(container)
            guard let session = try WearSessionService.activeSession(context: context) else { return }
            try WearSessionService.endSession(session, endedAt: Date(), context: context)
        } catch {
            // Sem tratamento adicional — melhor esforço, ver comentário acima.
        }
        await LiveActivityService.endWearingSession()
    }
}
