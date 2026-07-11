import Foundation
import Observation
import SwiftData

/// Estado e ações do cuidado rotineiro pós-remoção (`RoutineCareLog`): registrar o de hoje ou
/// com detalhes.
@MainActor
@Observable
final class RoutineCareViewModel {
    var presentedError: IdentifiableError?

    func registerRoutineCareToday(context: ModelContext) {
        registerRoutineCare(date: Date(), discardedSolution: true, cleanedCase: true, airDried: true, notes: nil, context: context)
    }

    func registerRoutineCare(date: Date, discardedSolution: Bool, cleanedCase: Bool, airDried: Bool, notes: String?, context: ModelContext) {
        do {
            try RoutineCareService.registerCare(
                date: date, discardedSolution: discardedSolution, cleanedCase: cleanedCase,
                airDried: airDried, notes: notes, context: context
            )
            HapticsService.success()
        } catch {
            HapticsService.error()
            presentedError = IdentifiableError(message: error.localizedDescription)
        }
    }
}
