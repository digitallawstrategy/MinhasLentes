import Foundation
import SwiftData

/// Um registro de limpeza do estojo de lentes. O ciclo de lembretes é sempre recalculado
/// a partir da limpeza mais recente, independentemente da quantidade de usos das lentes.
@Model
final class CaseCleaning {
    var id: UUID = UUID()
    var cleaningDate: Date = Date()
    var notes: String?
    var createdAt: Date = Date()

    init(id: UUID = UUID(), cleaningDate: Date, notes: String? = nil) {
        self.id = id
        self.cleaningDate = cleaningDate
        self.notes = notes
        self.createdAt = Date()
    }
}
