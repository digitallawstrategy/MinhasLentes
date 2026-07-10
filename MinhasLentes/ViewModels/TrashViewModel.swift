import Foundation
import Observation
import SwiftData

/// Estado e ações da tela Lixeira: restaurar um par ou excluí-lo de vez.
@MainActor
@Observable
final class TrashViewModel {
    var presentedError: IdentifiableError?
    var pairToPermanentlyDelete: LensPair?

    func restorePair(_ pair: LensPair, context: ModelContext) {
        do {
            try LensPairService.restoreFromTrash(pair, context: context)
            HapticsService.success()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível restaurar o par. \(error.localizedDescription)")
        }
    }

    func permanentlyDelete(_ pair: LensPair, context: ModelContext) {
        do {
            try LensPairService.permanentlyDeletePair(pair, context: context)
            HapticsService.lightImpact()
        } catch {
            presentedError = IdentifiableError(message: "Não foi possível excluir o par. \(error.localizedDescription)")
        }
    }
}
