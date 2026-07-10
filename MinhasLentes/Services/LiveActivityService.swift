import Foundation
import ActivityKit

/// Inicia, atualiza e encerra as Live Activities de lentes: a confirmação curta exibida ao
/// registrar um uso e a sessão opcional "Estou usando as lentes". Live Activity é um recurso
/// incremental — se não puder ser exibida (ex.: usuário desativou nos Ajustes do iPhone), o
/// app continua funcionando normalmente sem ela, sem propagar erro para a UI.
///
/// Toda busca/comparação de atividade usa `pair.id` (UUID), nunca `pair.name` — o nome pode
/// ser editado ou repetido entre pares diferentes, o que faria a sessão errada aparecer.
///
/// `Activity.request` pode falhar por causas transitórias e completamente alheias aos dados
/// atuais — por exemplo, uma atividade órfã de uma versão anterior do app que o sistema ainda
/// contava como "ativa" mas que o app não consegue mais decodificar (aconteceu de verdade ao
/// adicionar `pairID` em `LensActivityAttributes`). Como esse tipo de erro é sempre engolido em
/// silêncio, `showUsageConfirmation`/`startWearingSession` tentam de novo uma vez, depois de
/// encerrar toda e qualquer atividade órfã — sem isso, o recurso pode parar de funcionar sem
/// nenhum aviso, e sem o app estar instalado num build DEBUG não há como o usuário se recuperar
/// sozinho (nem reinstalar sempre limpa esse estado, que vive no sistema, não no app).
@MainActor
enum LiveActivityService {

    private static let usageConfirmationDuration: Duration = .seconds(8)

    /// Mostra por alguns segundos uma Live Activity curta confirmando o uso registrado. Não
    /// interrompe uma sessão "Estou usando as lentes" já em andamento.
    static func showUsageConfirmation(pairID: UUID, pairName: String, usesRemaining: Int, maximumUses: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !hasActiveWearingSession() else { return }

        let attributes = LensActivityAttributes(pairID: pairID, pairName: pairName)
        let state = LensActivityAttributes.ContentState(
            mode: .usageConfirmation,
            usesRemaining: usesRemaining,
            maximumUses: maximumUses,
            wearingSince: nil,
            reminderAt: nil
        )
        Task {
            guard await Self.requestActivityWithRecovery(attributes: attributes, state: state, staleDate: nil) else { return }
            try? await Task.sleep(for: usageConfirmationDuration)
            await Self.endActivity(forPairID: pairID)
        }
    }

    // MARK: - Sessão "Estou usando as lentes"

    static func hasActiveWearingSession() -> Bool {
        activeWearingSessionPairID() != nil
    }

    static func activeWearingSessionPairID() -> UUID? {
        Activity<LensActivityAttributes>.activities.first { $0.content.state.mode == .wearingSession }?.attributes.pairID
    }

    /// Inicia a sessão e agenda o lembrete local de remoção. Retorna `false` (sem lançar erro)
    /// se as Live Activities estiverem desativadas, já houver uma sessão em andamento, ou não
    /// for possível iniciar mesmo depois de tentar recuperar de um estado órfão.
    @discardableResult
    static func startWearingSession(
        pairID: UUID,
        pairName: String,
        usesRemaining: Int,
        maximumUses: Int,
        settings: AppSettings
    ) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !hasActiveWearingSession() else { return false }

        let now = Date()
        let reminderAt = Calendar.current.date(byAdding: .hour, value: settings.wearingReminderHours, to: now)
            ?? now.addingTimeInterval(Double(settings.wearingReminderHours) * 3600)

        let attributes = LensActivityAttributes(pairID: pairID, pairName: pairName)
        let state = LensActivityAttributes.ContentState(
            mode: .wearingSession,
            usesRemaining: usesRemaining,
            maximumUses: maximumUses,
            wearingSince: now,
            reminderAt: reminderAt
        )
        guard await Self.requestActivityWithRecovery(attributes: attributes, state: state, staleDate: reminderAt) else {
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

    #if DEBUG
    // MARK: - Diagnóstico (apenas builds DEBUG)

    static func debugActivitiesSummary() -> String {
        let activities = Activity<LensActivityAttributes>.activities
        guard !activities.isEmpty else { return "Nenhuma Live Activity em execução." }
        return activities.map { activity in
            let state = activity.content.state
            return "• \(activity.attributes.pairName) (\(activity.attributes.pairID)) — \(state.mode.rawValue), restam \(state.usesRemaining)"
        }.joined(separator: "\n")
    }

    static func endAllActivitiesForDebugging() async {
        await Self.endAllActivitiesInternal()
        NotificationManager.shared.cancelWearingReminder()
    }
    #endif

    // MARK: - Fora do MainActor
    //
    // `Activity.end(_:dismissalPolicy:)`/`Activity.request` são `nonisolated`; sob a checagem
    // estrita de concorrência do Swift 6, fazer a busca e a chamada dentro destes helpers
    // `nonisolated` evita que o valor fique "preso" à região do MainActor antes da chamada.

    /// Tenta pedir a atividade; se falhar, encerra qualquer atividade órfã deste app e tenta
    /// mais uma vez antes de desistir. Nunca lança erro — retorna se conseguiu ou não.
    nonisolated private static func requestActivityWithRecovery(
        attributes: LensActivityAttributes,
        state: LensActivityAttributes.ContentState,
        staleDate: Date?
    ) async -> Bool {
        if (try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: staleDate))) != nil {
            return true
        }
        await Self.endAllActivitiesInternal()
        return (try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: staleDate))) != nil
    }

    nonisolated private static func endActivity(forPairID pairID: UUID) async {
        guard let current = Activity<LensActivityAttributes>.activities.first(where: { $0.attributes.pairID == pairID }) else { return }
        await current.end(nil, dismissalPolicy: .immediate)
    }

    nonisolated private static func endAllWearingActivities() async {
        for activity in Activity<LensActivityAttributes>.activities where activity.content.state.mode == .wearingSession {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    nonisolated private static func endAllActivitiesInternal() async {
        for activity in Activity<LensActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
