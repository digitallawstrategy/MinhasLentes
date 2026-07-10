import Foundation

/// Um grupo de itens do Histórico exibidos sob um mesmo cabeçalho de data (Hoje, Ontem, ...).
struct HistorySection: Identifiable {
    let id: String
    let title: String
    let items: [HistoryItem]
}

/// Agrupa uma lista de `HistoryItem` já ordenada (mais recente primeiro) em seções de data,
/// no estilo comum em apps iOS. Função pura, sem dependência de SwiftData, para facilitar testes.
enum HistoryGrouping {
    static func group(_ items: [HistoryItem], now: Date = Date(), calendar: Calendar = .current) -> [HistorySection] {
        var buckets: [String: [HistoryItem]] = [:]
        var order: [String] = []
        for item in items {
            let title = sectionTitle(for: item.date, now: now, calendar: calendar)
            if buckets[title] == nil {
                buckets[title] = []
                order.append(title)
            }
            buckets[title, default: []].append(item)
        }
        return order.map { HistorySection(id: $0, title: $0, items: buckets[$0] ?? []) }
    }

    /// Usa `now` explicitamente em vez de `Calendar.isDateInToday`/`isDateInYesterday`, que
    /// sempre comparam contra o relógio real do aparelho — o que quebraria tanto os testes
    /// (que fixam `now`) quanto qualquer chamador que precise agrupar em relação a outra data.
    private static func sectionTitle(for date: Date, now: Date, calendar: Calendar) -> String {
        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)
        guard let daysAgo = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day else {
            return "Mais antigos"
        }
        if daysAgo == 0 { return "Hoje" }
        if daysAgo == 1 { return "Ontem" }
        if daysAgo > 0, daysAgo <= 7 { return "Esta semana" }
        if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return "Este mês"
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return "Este ano"
        }
        return "Mais antigos"
    }
}
