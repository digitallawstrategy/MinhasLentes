import AppIntents
import SwiftData

/// "Siri, tirei as lentes" — encerra a sessão de uso ativa (se houver), a Live Activity e as
/// notificações de tempo excessivo, exatamente como o botão "Retirei as lentes" da Home. Sem
/// sessão ativa é um no-op idempotente, não um erro (repetir o comando depois de já ter
/// encerrado não deve falhar).
struct EndWearingLensesIntent: AppIntent {
    static let title: LocalizedStringResource = "Tirei as lentes"
    static let description = IntentDescription("Encerra a sessão de uso das lentes, se houver uma ativa.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(try AppContainer.shared())
        let outcome = try await LensRoutineCommandService.endWearing(context: context)
        return .result(dialog: IntentDialog(stringLiteral: responseText(for: outcome)))
    }

    private func responseText(for outcome: LensRoutineCommandService.EndWearingOutcome) -> String {
        switch outcome {
        case .noActiveSession:
            return "Nenhuma sessão de uso ativa encontrada."
        case .ended:
            return "Sessão encerrada."
        }
    }
}
