import AppIntents
import SwiftData

/// "Siri, estou de lentes" — App Intent (não SiriKit legado). Roda em segundo plano, sem abrir o
/// app (`openAppWhenRun = false`): registra o uso de hoje quando aplicável e inicia a sessão
/// "Estou usando as lentes", exatamente como o fluxo já existente na Home, só disparado por voz.
/// Nenhuma regra de negócio mora aqui — tudo delegado a `LensRoutineCommandService`.
struct StartWearingLensesIntent: AppIntent {
    static let title: LocalizedStringResource = "Estou de lentes"
    static let description = IntentDescription("Registra o uso de hoje e inicia a sessão de uso das lentes, se ainda não estiver ativa.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(try AppContainer.shared())
        let settings = try AppSettingsStore.currentSettings(context: context)
        let outcome = try await LensRoutineCommandService.startWearing(context: context, settings: settings)
        return .result(dialog: IntentDialog(stringLiteral: responseText(for: outcome)))
    }

    private func responseText(for outcome: LensRoutineCommandService.StartWearingOutcome) -> String {
        switch outcome {
        case .noPairInUse:
            return "Não encontrei um par em uso. Abra o app para iniciar um par."
        case .sessionAlreadyActive:
            return "Você já está com uma sessão de uso ativa."
        case .usageLimitReached:
            return "Limite de usos atingido. Sessão iniciada."
        case .usageAlreadyRegisteredTodaySessionStarted:
            return "Sessão iniciada. O uso de hoje já estava registrado."
        case .registeredAndStarted:
            return "Uso registrado. Sessão iniciada."
        }
    }
}
