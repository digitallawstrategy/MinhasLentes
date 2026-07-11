import Foundation

/// Funções puras de agregação sobre o estoque de lentes (`LensInventoryItem`). Separado de
/// `LensStatisticsService` porque este modelo não é compartilhado com o alvo do widget — mantê-lo
/// à parte evita puxar `LensInventoryItem` para um target que nunca precisa dele.
enum LensInventoryStatisticsService {

    /// Soma da quantidade restante nos itens informados, opcionalmente filtrada por lado —
    /// usada no resumo de estoque da aba Lentes.
    static func totalRemainingQuantity(items: [LensInventoryItem], side: LensSide? = nil) -> Int {
        items
            .filter { side == nil || $0.side == side }
            .reduce(0) { $0 + $1.remainingQuantity }
    }

    /// Validade mais próxima entre os itens informados (ignora itens sem validade cadastrada).
    static func nearestExpiry(items: [LensInventoryItem]) -> Date? {
        items.compactMap(\.expiryDate).min()
    }

    /// Itens cuja validade cai dentro da janela informada, incluindo os já vencidos — a mesma
    /// noção de "perto do prazo" usada nos lembretes de estojo/solução, aplicada ao estoque.
    static func itemsNearExpiry(
        items: [LensInventoryItem],
        withinDays: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [LensInventoryItem] {
        items.filter { item in
            guard let expiryDate = item.expiryDate else { return false }
            return LensStatisticsService.daysUntil(expiryDate, referenceDate: referenceDate, calendar: calendar) <= withinDays
        }
    }

    /// Limiar fixo de "estoque baixo" — não há configuração para isso em `AppSettings` ainda;
    /// um valor conservador evita alertar cedo demais para quem compra caixas avulsas.
    static let lowStockThreshold = 2

    static func isLowStock(_ item: LensInventoryItem) -> Bool {
        item.status == .available && item.remainingQuantity > 0 && item.remainingQuantity <= lowStockThreshold
    }
}
