import Foundation
import SwiftData

/// Orquestra o comando de voz "Estou de lentes"/"Tirei as lentes" (App Intents) reusando os
/// serviços já existentes — nenhuma regra de negócio nova mora aqui, só a sequência de chamadas
/// e a decisão de qual das 5 respostas idempotentes se aplica. Não usa `LensPairsViewModel` de
/// propósito: aquele tipo é `@MainActor @Observable` com estado de UI (toasts, alerts) que não
/// faz sentido fora de uma View — um App Intent chama os Services diretamente, como
/// `NotificationManager.endWearingSessionDirectly()` já faz para o botão de notificação.
@MainActor
enum LensRoutineCommandService {
    enum StartWearingOutcome: Equatable {
        /// Nenhum par com status `.inUse` encontrado.
        case noPairInUse
        /// Já havia uma sessão de uso ativa — nada foi criado ou registrado (idempotente).
        case sessionAlreadyActive
        /// O par já atingiu `maximumUses`; a sessão inicia mesmo assim, sem registrar uso novo —
        /// mesmo comportamento já existente hoje na Home (`registerUsageToday` e
        /// `toggleWearingSession` são independentes no fluxo do diálogo de confirmação: um limite
        /// atingido não impede o início da sessão).
        case usageLimitReached
        /// Já existia uso registrado hoje para este par (e `allowMultipleUsesPerDay` está
        /// desligado) — não duplica, só inicia a sessão.
        case usageAlreadyRegisteredTodaySessionStarted
        /// Caminho normal: sem uso hoje (ou `allowMultipleUsesPerDay` ligado), registra o uso e
        /// inicia a sessão.
        case registeredAndStarted
    }

    enum EndWearingOutcome: Equatable {
        case noActiveSession
        case ended
    }

    /// Ponto de entrada de "Estou de lentes". Prioridade das checagens, da mais para a menos
    /// idempotente: sessão já ativa vence tudo (nem olha para par/uso); depois par inexistente;
    /// depois o resultado real da tentativa de registrar uso (delegado inteiramente a
    /// `LensPairService.registerUsage`, que já sabe as regras de duplicidade/limite/múltiplos
    /// usos por dia — este método não reimplementa nenhuma delas, só reage ao que o service
    /// decidiu).
    static func startWearing(context: ModelContext, settings: AppSettings) async throws -> StartWearingOutcome {
        if try WearSessionService.activeSession(context: context) != nil {
            return .sessionAlreadyActive
        }

        guard let pair = try LensPairService.inUsePairs(context: context).first else {
            return .noPairInUse
        }

        var usageAlreadyRegisteredToday = false
        var usageLimitReached = false
        do {
            try LensPairService.registerUsage(
                for: pair, date: Date(), side: pair.side, notes: nil,
                allowMultipleUsesPerDay: settings.allowMultipleUsesPerDay, forceDuplicate: false,
                context: context
            )
        } catch LensPairService.ServiceError.duplicateUsageOnDate {
            usageAlreadyRegisteredToday = true
        } catch LensPairService.ServiceError.limitReached {
            usageLimitReached = true
        }
        // Qualquer outro erro (ex.: `.persistenceFailed`) propaga — não é um dos 5 desfechos
        // esperados, é uma falha real que o chamador (o `AppIntent`) precisa saber que aconteceu.

        let session = try WearSessionService.startSession(for: pair, startedAt: Date(), context: context)

        // Live Activity e notificação são melhor-esforço, como já é em `LensPairsViewModel` —
        // nunca devem derrubar o comando de voz por falta de permissão do sistema.
        _ = await LiveActivityService.presentWearingSession(
            pairID: pair.id, pairName: pair.name, usesRemaining: pair.usesRemaining, maximumUses: pair.maximumUses,
            wearingSince: session.startedAt, settings: settings
        )
        try? await NotificationManager.shared.scheduleWearingExcessiveNotifications(wearingSince: session.startedAt, settings: settings)

        if usageLimitReached { return .usageLimitReached }
        return usageAlreadyRegisteredToday ? .usageAlreadyRegisteredTodaySessionStarted : .registeredAndStarted
    }

    /// Ponto de entrada de "Tirei as lentes". Encerrar sem sessão ativa é um no-op idempotente
    /// (não um erro) — repetir o comando depois que já encerrou não deve falhar.
    static func endWearing(context: ModelContext) async throws -> EndWearingOutcome {
        guard let session = try WearSessionService.activeSession(context: context) else {
            return .noActiveSession
        }
        try WearSessionService.endSession(session, endedAt: Date(), context: context)
        // Também cancela as notificações de tempo excessivo — ver `LiveActivityService.endWearingSession`.
        await LiveActivityService.endWearingSession()
        return .ended
    }
}
