import Foundation

/// Uma entrada da "Diário das Lentes": a linha do tempo completa da vida útil de um único par,
/// do início ao fim, incluindo os avisos de status de utilização cruzados ao longo do caminho.
struct PairDiaryEntry: Identifiable {
    let id: String
    let date: Date
    let emoji: String
    let title: String
    let subtitle: String?
}

/// Monta a linha do tempo de um par específico a partir dos seus usos, das limpezas do
/// estojo feitas durante a vida do par e dos marcos de início/encerramento. Função pura, sem
/// dependência de SwiftData, para facilitar testes.
enum PairDiaryBuilder {
    static func build(
        pair: LensPair,
        allCleanings: [CaseCleaning],
        warningBelowPercent: Int
    ) -> [PairDiaryEntry] {
        var entries: [PairDiaryEntry] = []

        entries.append(PairDiaryEntry(
            id: "start-\(pair.id)",
            date: pair.startDate,
            emoji: "📅",
            title: "Par iniciado",
            subtitle: nil
        ))

        let ascendingUsages = (pair.usages ?? []).sorted { $0.date < $1.date }
        var crossedWarning = false
        for (index, usage) in ascendingUsages.enumerated() {
            let usageNumber = index + 1
            entries.append(PairDiaryEntry(
                id: "usage-\(usage.id)",
                date: usage.date,
                emoji: "👁️",
                title: "Uso nº \(usageNumber)",
                subtitle: usage.notes
            ))

            let remaining = max(0, pair.maximumUses - usageNumber)
            if !crossedWarning, pair.maximumUses > 0 {
                let remainingPercent = Int((Double(remaining) / Double(pair.maximumUses) * 100).rounded())
                if remainingPercent < warningBelowPercent {
                    crossedWarning = true
                    entries.append(PairDiaryEntry(
                        id: "warning-\(pair.id)",
                        date: usage.date,
                        emoji: "⚠️",
                        title: "Restam \(remaining) utilizações",
                        subtitle: nil
                    ))
                }
            }
        }

        let periodEnd = pair.endDate ?? .distantFuture
        let cleaningsDuringPair = allCleanings
            .filter { $0.cleaningDate >= pair.startDate && $0.cleaningDate <= periodEnd }
            .sorted { $0.cleaningDate < $1.cleaningDate }
        for cleaning in cleaningsDuringPair {
            entries.append(PairDiaryEntry(
                id: "cleaning-\(cleaning.id)",
                date: cleaning.cleaningDate,
                emoji: "🧼",
                title: "Estojo limpo",
                subtitle: cleaning.notes
            ))
        }

        if pair.status == .finished, let endDate = pair.endDate {
            let reason = pair.discardReasonValue?.displayName ?? "não informado"
            entries.append(PairDiaryEntry(
                id: "end-\(pair.id)",
                date: endDate,
                emoji: "🔄",
                title: "Par substituído",
                subtitle: "Motivo: \(reason)"
            ))
        }

        return entries.sorted { $0.date < $1.date }
    }
}
