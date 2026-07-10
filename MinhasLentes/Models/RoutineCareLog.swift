import Foundation
import SwiftData

/// Registro de cuidado rotineiro pós-remoção das lentes — descartar a solução usada, limpar o
/// estojo e deixá-lo secar ao ar livre. Distinto da limpeza periódica (`CaseCleaning`, que segue
/// um intervalo configurável e dispara notificações): a rotina é um hábito diário, sem prazo.
@Model
final class RoutineCareLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var discardedSolution: Bool = true
    var cleanedCase: Bool = true
    var airDried: Bool = true
    var notes: String?
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        date: Date,
        discardedSolution: Bool = true,
        cleanedCase: Bool = true,
        airDried: Bool = true,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.discardedSolution = discardedSolution
        self.cleanedCase = cleanedCase
        self.airDried = airDried
        self.notes = notes
        self.createdAt = Date()
    }
}
