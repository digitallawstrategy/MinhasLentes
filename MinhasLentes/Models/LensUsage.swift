import Foundation
import SwiftData

/// Um registro individual de uso das lentes em uma data específica.
@Model
final class LensUsage {
    var id: UUID = UUID()
    var date: Date = Date()
    var sideRawValue: String = LensSide.both.rawValue
    var notes: String?
    var createdAt: Date = Date()

    var lensPair: LensPair?

    init(
        id: UUID = UUID(),
        date: Date,
        side: LensSide,
        notes: String? = nil,
        lensPair: LensPair? = nil
    ) {
        self.id = id
        self.date = date
        self.sideRawValue = side.rawValue
        self.notes = notes
        self.createdAt = Date()
        self.lensPair = lensPair
    }

    var side: LensSide {
        get { LensSide(rawValue: sideRawValue) ?? .both }
        set { sideRawValue = newValue.rawValue }
    }
}
