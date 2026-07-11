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
/// silêncio, `showUsageConfirmation`/`presentWearingSession` tentam de novo uma vez, depois de
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

    /// Apresenta a Live Activity da sessão de uso a partir de um `WearSession` já persistido —
    /// esta função nunca cria nem decide sobre a sessão em si, apenas a exibe. Usada tanto para
    /// iniciar uma sessão nova (`wearingSince` = agora) quanto para restaurá-la ao abrir o app
    /// depois que o sistema encerrou a Live Activity, o widget reiniciou, ou o iPhone reiniciou
    /// (`wearingSince` = quando a sessão realmente começou, possivelmente horas atrás). Retorna
    /// `false` sem lançar erro se as Live Activities estiverem desativadas, já houver uma sessão
    /// em andamento, ou não for possível apresentar mesmo depois de tentar recuperar de um
    /// estado órfão — a sessão persistida continua válida de qualquer forma.
    @discardableResult
    static func presentWearingSession(
        pairID: UUID,
        pairName: String,
        usesRemaining: Int,
        maximumUses: Int,
        wearingSince: Date,
        settings: AppSettings
    ) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, !hasActiveWearingSession() else { return false }

        let nextThreshold = nextProgressiveThreshold(wearingSince: wearingSince, settings: settings)
        let attributes = LensActivityAttributes(pairID: pairID, pairName: pairName)
        let state = LensActivityAttributes.ContentState(
            mode: .wearingSession,
            usesRemaining: usesRemaining,
            maximumUses: maximumUses,
            wearingSince: wearingSince,
            reminderAt: nextThreshold
        )
        return await Self.requestActivityWithRecovery(attributes: attributes, state: state, staleDate: nextThreshold)
    }

    /// Próximo dos três avisos fixos ainda no futuro; se todos já passaram, o próximo horário
    /// do lembrete repetitivo, contado a partir de agora — usado só para `staleDate`/exibição,
    /// nunca para agendar notificação (isso é `NotificationManager.scheduleWearingExcessiveNotifications`).
    private static func nextProgressiveThreshold(wearingSince: Date, settings: AppSettings) -> Date {
        let offsets = [settings.wearingReminderHours, settings.wearingReminderHours + 1, settings.wearingReminderHours + 2]
        for offset in offsets {
            let candidate = wearingSince.addingTimeInterval(Double(offset) * 3600)
            if candidate > Date() { return candidate }
        }
        return Date().addingTimeInterval(Double(max(1, settings.wearingExcessiveRepeatIntervalHours)) * 3600)
    }

    static func endWearingSession() async {
        await Self.endAllWearingActivities()
        NotificationManager.shared.cancelWearingExcessiveNotifications()
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
        NotificationManager.shared.cancelWearingExcessiveNotifications()
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
