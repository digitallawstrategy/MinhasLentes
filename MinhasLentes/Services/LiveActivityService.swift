import Foundation
import ActivityKit

/// Inicia, atualiza e encerra as Live Activities de lentes: a confirmação curta exibida ao
/// registrar um uso e a sessão opcional "Estou usando as lentes". Live Activity é um recurso
/// incremental — se não puder ser exibida (ex.: usuário desativou nos Ajustes do iPhone), o
/// app continua funcionando normalmente sem ela, sem propagar erro para a UI.
@MainActor
enum LiveActivityService {

    private static let usageConfirmationDuration: Duration = .seconds(8)

    /// Mostra por alguns segundos uma Live Activity curta confirmando o uso registrado. Não
    /// interrompe uma sessão "Estou usando as lentes" já em andamento.
    static func showUsageConfirmation(pairName: String, usesRemaining: Int, maximumUses: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !hasActiveWearingSession() else { return }

        let attributes = LensActivityAttributes(pairName: pairName)
        let state = LensActivityAttributes.ContentState(
            mode: .usageConfirmation,
            usesRemaining: usesRemaining,
            maximumUses: maximumUses,
            wearingSince: nil,
            reminderAt: nil
        )
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            // Melhor esforço: sem Live Activity, o app segue funcionando normalmente.
            return
        }
        Task {
            try? await Task.sleep(for: usageConfirmationDuration)
            await Self.endActivity(matching: attributes)
        }
    }

    // MARK: - Sessão "Estou usando as lentes"

    static func hasActiveWearingSession() -> Bool {
        activeWearingSessionPairName() != nil
    }

    static func activeWearingSessionPairName() -> String? {
        Activity<LensActivityAttributes>.activities.first { $0.content.state.mode == .wearingSession }?.attributes.pairName
    }

    /// Inicia a sessão e agenda o lembrete local de remoção. Retorna `false` (sem lançar erro)
    /// se as Live Activities estiverem desativadas ou já houver uma sessão em andamento.
    @discardableResult
    static func startWearingSession(
        pairName: String,
        usesRemaining: Int,
        maximumUses: Int,
        settings: AppSettings
    ) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !hasActiveWearingSession() else { return false }

        let now = Date()
        let reminderAt = Calendar.current.date(byAdding: .hour, value: settings.wearingReminderHours, to: now)
            ?? now.addingTimeInterval(Double(settings.wearingReminderHours) * 3600)

        let attributes = LensActivityAttributes(pairName: pairName)
        let state = LensActivityAttributes.ContentState(
            mode: .wearingSession,
            usesRemaining: usesRemaining,
            maximumUses: maximumUses,
            wearingSince: now,
            reminderAt: reminderAt
        )
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: reminderAt))
        } catch {
            return false
        }
        // Melhor esforço: se o lembrete não puder ser agendado (ex.: notificações não
        // autorizadas), a sessão continua ativa normalmente — só o alerta extra é perdido.
        try? await NotificationManager.shared.scheduleWearingReminder(at: reminderAt, settings: settings)
        return true
    }

    static func endWearingSession() async {
        await Self.endAllWearingActivities()
        NotificationManager.shared.cancelWearingReminder()
    }

    // MARK: - Encerramento fora do MainActor
    //
    // `Activity.end(_:dismissalPolicy:)` é `nonisolated`; sob a checagem estrita de
    // concorrência do Swift 6, buscar e encerrar a atividade nestes helpers `nonisolated`
    // evita que o valor fique "preso" à região do MainActor antes da chamada.

    nonisolated private static func endActivity(matching attributes: LensActivityAttributes) async {
        guard let current = Activity<LensActivityAttributes>.activities.first(where: { $0.attributes == attributes }) else { return }
        await current.end(nil, dismissalPolicy: .immediate)
    }

    nonisolated private static func endAllWearingActivities() async {
        for activity in Activity<LensActivityAttributes>.activities where activity.content.state.mode == .wearingSession {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
