import Foundation
import SwiftData

/// Evento administrativo de auditoria (início/encerramento de par, edição ou exclusão de uso,
/// limpeza registrada). Mantido separado dos registros originais para preservar o histórico
/// mesmo quando o registro que o originou é editado ou excluído.
@Model
final class HistoryEvent {
    var id: UUID = UUID()
    var eventTypeRawValue: String = HistoryEventType.usageAdded.rawValue
    var eventDate: Date = Date()
    var lensPairID: UUID?
    var lensPairName: String?
    var sideRawValue: String?
    var descriptionText: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        eventType: HistoryEventType,
        eventDate: Date,
        lensPairID: UUID? = nil,
        lensPairName: String? = nil,
        side: LensSide? = nil,
        descriptionText: String
    ) {
        self.id = id
        self.eventTypeRawValue = eventType.rawValue
        self.eventDate = eventDate
        self.lensPairID = lensPairID
        self.lensPairName = lensPairName
        self.sideRawValue = side?.rawValue
        self.descriptionText = descriptionText
        self.createdAt = Date()
    }

    var eventType: HistoryEventType {
        get { HistoryEventType(rawValue: eventTypeRawValue) ?? .usageAdded }
        set { eventTypeRawValue = newValue.rawValue }
    }

    var side: LensSide? {
        get { sideRawValue.flatMap { LensSide(rawValue: $0) } }
        set { sideRawValue = newValue?.rawValue }
    }
}
