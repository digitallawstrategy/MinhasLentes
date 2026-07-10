import Foundation
import SwiftData

/// Representa um par de lentes (modo "por par") ou um lado isolado — direito ou esquerdo —
/// quando o aplicativo está em modo individual. Cada `LensPair` possui seu próprio ciclo de
/// vida: início, usos, encerramento e motivo de descarte.
@Model
final class LensPair {
    var id: UUID = UUID()
    var name: String = ""
    var sequenceNumber: Int = 1
    var startDate: Date = Date()
    var endDate: Date?
    var maximumUses: Int = 60
    var statusRawValue: String = LensPairStatus.inUse.rawValue
    var discardReason: String?
    var notes: String?
    var trackingModeRawValue: String = TrackingMode.pair.rawValue
    var sideRawValue: String = LensSide.both.rawValue
    var createdAt: Date = Date()

    /// Quando não-nulo, o par está na lixeira: escondido do restante do app, mas recuperável
    /// até `LensPairService.trashRetentionDays` depois desta data, quando é apagado de vez.
    var deletedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \LensUsage.lensPair)
    var usages: [LensUsage]? = []

    init(
        id: UUID = UUID(),
        name: String,
        sequenceNumber: Int,
        startDate: Date,
        maximumUses: Int,
        trackingMode: TrackingMode,
        side: LensSide
    ) {
        self.id = id
        self.name = name
        self.sequenceNumber = sequenceNumber
        self.startDate = startDate
        self.maximumUses = maximumUses
        self.statusRawValue = LensPairStatus.inUse.rawValue
        self.trackingModeRawValue = trackingMode.rawValue
        self.sideRawValue = side.rawValue
        self.createdAt = Date()
    }

    var status: LensPairStatus {
        get { LensPairStatus(rawValue: statusRawValue) ?? .inUse }
        set { statusRawValue = newValue.rawValue }
    }

    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRawValue) ?? .pair }
        set { trackingModeRawValue = newValue.rawValue }
    }

    var side: LensSide {
        get { LensSide(rawValue: sideRawValue) ?? .both }
        set { sideRawValue = newValue.rawValue }
    }

    var discardReasonValue: DiscardReason? {
        get { discardReason.flatMap { DiscardReason(rawValue: $0) } }
        set { discardReason = newValue?.rawValue }
    }

    /// Usos válidos (registros associados a este par), ordenados do mais recente para o mais antigo.
    var sortedUsages: [LensUsage] {
        (usages ?? []).sorted { $0.date > $1.date }
    }

    var usesCount: Int {
        (usages ?? []).count
    }

    var usesRemaining: Int {
        max(0, maximumUses - usesCount)
    }

    var lifeUsedFraction: Double {
        guard maximumUses > 0 else { return 0 }
        return min(1.0, Double(usesCount) / Double(maximumUses))
    }

    var hasReachedLimit: Bool {
        usesCount >= maximumUses
    }

    var lastUsageDate: Date? {
        sortedUsages.first?.date
    }
}
