import Foundation
import SwiftData

/// Situação de um ciclo de estojo. No máximo um `LensCase` fica `.active` por vez — substituir
/// o estojo encerra automaticamente o ciclo atual (`.replaced`) e inicia um novo.
enum LensCaseStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case replaced

    var displayName: String {
        switch self {
        case .active: return "Em uso"
        case .replaced: return "Substituído"
        }
    }
}

/// Um ciclo de vida do estojo físico de lentes — desde que passou a ser usado até ser
/// substituído por um novo. Independente do ciclo de limpeza (`CaseCleaning`/`RoutineCareLog`):
/// um estojo pode ser limpo várias vezes ao longo do mesmo ciclo de uso.
@Model
final class LensCase {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var replacedAt: Date?
    /// Intervalo recomendado de substituição, em dias, copiado de `AppSettings` no momento em
    /// que o ciclo começou — preserva o histórico mesmo que a preferência mude depois.
    var intervalDays: Int = 90
    var notes: String?
    var statusRawValue: String = LensCaseStatus.active.rawValue
    var createdAt: Date = Date()

    init(id: UUID = UUID(), startDate: Date, intervalDays: Int, notes: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.intervalDays = intervalDays
        self.notes = notes
        self.statusRawValue = LensCaseStatus.active.rawValue
        self.createdAt = Date()
    }

    var status: LensCaseStatus {
        get { LensCaseStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var nextRecommendedReplacementDate: Date {
        LensStatisticsService.nextCaseReplacementDate(startDate: startDate, intervalDays: intervalDays)
    }
}
