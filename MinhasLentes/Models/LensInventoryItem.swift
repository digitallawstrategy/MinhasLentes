import Foundation
import SwiftData

/// Situação de um item em estoque. Ao contrário de `LensCase`/`CleaningSolution`, vários itens
/// podem estar `.available` ao mesmo tempo — não existe conceito de "um ativo por vez" aqui,
/// já que uma pessoa pode ter várias caixas compradas simultaneamente.
enum LensInventoryStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case available
    case exhausted

    var displayName: String {
        switch self {
        case .available: return "Disponível"
        case .exhausted: return "Esgotado"
        }
    }
}

/// Uma caixa de lentes comprada e guardada em estoque — distinta dos pares em uso (`LensPair`).
/// Ao iniciar um novo par, o app pode perguntar se o usuário quer usar uma lente do estoque,
/// o que reduz `remainingQuantity` automaticamente; ao chegar a zero, o item vira `.exhausted`.
@Model
final class LensInventoryItem {
    var id: UUID = UUID()
    var brand: String = ""
    var model: String = ""
    /// Grau do olho direito, texto livre (ex.: "-2.00") — a notação de grau varia demais
    /// (esférico, cilíndrico, eixo, adição) para valer a pena estruturar em campos separados.
    var prescriptionOD: String?
    /// Grau do olho esquerdo, mesmo raciocínio de `prescriptionOD`.
    var prescriptionOS: String?
    /// Para qual(is) olho(s) esta caixa se destina — usado para filtrar o estoque disponível
    /// ao iniciar um novo par de um lado específico.
    var sideRawValue: String = LensSide.both.rawValue
    var lot: String?
    var expiryDate: Date?
    var initialQuantity: Int = 1
    var remainingQuantity: Int = 1
    /// Foto opcional da embalagem/receita, armazenada fora do arquivo principal do banco
    /// (`.externalStorage`) para não inflar o SQLite compartilhado com o widget via App Group.
    @Attribute(.externalStorage) var photoData: Data?
    var notes: String?
    var statusRawValue: String = LensInventoryStatus.available.rawValue
    var createdAt: Date = Date()

    /// Inverso de `LensPair.inventoryItem` — o `deleteRule: .nullify` precisa estar deste lado
    /// (o item sendo excluído), não no lado do par: testado e confirmado que anotar só
    /// `LensPair.inventoryItem` não fazia o SwiftData zerar a referência ao excluir o item
    /// vinculado. Na prática quase sempre 0 ou 1 elemento (um par por vez usa a caixa), mas o
    /// tipo continua array porque é o lado "muitos" da relação.
    @Relationship(deleteRule: .nullify, inverse: \LensPair.inventoryItem)
    var linkedPairs: [LensPair]? = []

    init(
        id: UUID = UUID(),
        brand: String,
        model: String,
        prescriptionOD: String? = nil,
        prescriptionOS: String? = nil,
        side: LensSide = .both,
        lot: String? = nil,
        expiryDate: Date? = nil,
        initialQuantity: Int,
        photoData: Data? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.prescriptionOD = prescriptionOD
        self.prescriptionOS = prescriptionOS
        self.sideRawValue = side.rawValue
        self.lot = lot
        self.expiryDate = expiryDate
        self.initialQuantity = initialQuantity
        self.remainingQuantity = initialQuantity
        self.photoData = photoData
        self.notes = notes
        self.statusRawValue = LensInventoryStatus.available.rawValue
        self.createdAt = Date()
    }

    var status: LensInventoryStatus {
        get { LensInventoryStatus(rawValue: statusRawValue) ?? .available }
        set { statusRawValue = newValue.rawValue }
    }

    var side: LensSide {
        get { LensSide(rawValue: sideRawValue) ?? .both }
        set { sideRawValue = newValue.rawValue }
    }

    var isExpired: Bool {
        guard let expiryDate else { return false }
        return expiryDate < Date()
    }
}
