import Foundation
import SwiftData

/// Situação de um frasco de solução de limpeza. No máximo um `CleaningSolution` fica `.active`
/// por vez — abrir um novo frasco encerra automaticamente o anterior (`.finished`).
enum CleaningSolutionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active
    case finished

    var displayName: String {
        switch self {
        case .active: return "Em uso"
        case .finished: return "Finalizado"
        }
    }
}

/// Um frasco de solução de limpeza de lentes, do momento em que é aberto até ser substituído.
/// A validade real após aberto é sempre a menor entre a data impressa pelo fabricante e o
/// prazo de validade pós-abertura também indicado pelo fabricante — nunca um prazo inventado.
@Model
final class CleaningSolution {
    var id: UUID = UUID()
    var brand: String = ""
    var product: String = ""
    var lot: String?
    var purchaseDate: Date?
    var openedDate: Date = Date()
    /// Validade impressa pelo fabricante no frasco. Opcional porque nem sempre está legível ou
    /// à mão no momento do registro — quando ausente, a validade pós-abertura decide sozinha.
    var printedExpiryDate: Date?
    /// Prazo de validade pós-abertura recomendado pelo fabricante, em dias.
    var postOpeningShelfLifeDays: Int = 90
    var initialVolumeML: Int?
    var remainingVolumeML: Int?
    var notes: String?
    var statusRawValue: String = CleaningSolutionStatus.active.rawValue
    var finishedAt: Date?
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        brand: String,
        product: String,
        lot: String? = nil,
        purchaseDate: Date? = nil,
        openedDate: Date,
        printedExpiryDate: Date? = nil,
        postOpeningShelfLifeDays: Int,
        initialVolumeML: Int? = nil,
        remainingVolumeML: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.brand = brand
        self.product = product
        self.lot = lot
        self.purchaseDate = purchaseDate
        self.openedDate = openedDate
        self.printedExpiryDate = printedExpiryDate
        self.postOpeningShelfLifeDays = postOpeningShelfLifeDays
        self.initialVolumeML = initialVolumeML
        self.remainingVolumeML = remainingVolumeML
        self.notes = notes
        self.statusRawValue = CleaningSolutionStatus.active.rawValue
        self.createdAt = Date()
    }

    var status: CleaningSolutionStatus {
        get { CleaningSolutionStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var discardDate: Date {
        LensStatisticsService.solutionDiscardDate(
            openedDate: openedDate,
            postOpeningShelfLifeDays: postOpeningShelfLifeDays,
            printedExpiryDate: printedExpiryDate
        )
    }
}
