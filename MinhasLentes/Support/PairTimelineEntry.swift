import Foundation

/// O tipo de acontecimento representado por uma `PairTimelineEntry` — usado tanto para escolher
/// o ícone/tom da linha quanto para o filtro de categoria em `PairTimelineView`.
enum PairTimelineEntryKind: Hashable {
    case start, usage, warning, session, cleaning, edit, end
}

/// Uma entrada da linha do tempo de um par: o que aconteceu, quando, e um detalhe opcional.
struct PairTimelineEntry: Identifiable {
    let id: String
    let date: Date
    let kind: PairTimelineEntryKind
    let title: String
    let subtitle: String?
}

/// Um grupo de entradas do mesmo mês/ano, já com o título pronto para exibição (ex.: "Julho de
/// 2026") — a granularidade certa para a vida de um par, que costuma durar meses, diferente dos
/// baldes relativos a hoje ("Hoje"/"Ontem") de `HistorySection`, feitos para o histórico geral do
/// app.
struct PairTimelineMonthGroup: Identifiable {
    let id: String
    let title: String
    let entries: [PairTimelineEntry]
}

/// Monta a linha do tempo completa de um par: início, usos (com o aviso de vida útil cruzado ao
/// longo do caminho), sessões de uso iniciadas/finalizadas, limpezas do estojo feitas durante o
/// período do par, edições/movimentações administrativas, e o encerramento. Função pura, sem
/// dependência de SwiftData, para facilitar testes — `events` já vem pré-filtrado pelo chamador
/// (`PairTimelineView` busca via `@Query` e filtra por `lensPairID`), este tipo não toca
/// `ModelContext`.
///
/// Cuidado diário (`RoutineCareLog`) fica de fora de propósito: não tem vínculo com `LensPair` —
/// é um registro do estojo, não do par — incluí-lo aqui seria dado enganoso, não esquecimento.
enum PairTimelineBuilder {
    /// Tipos de `HistoryEvent` relevantes para a linha do tempo de um par. `.pairStarted`/
    /// `.pairFinished` ficam de fora de propósito — já são derivados direto de
    /// `pair.startDate`/`endDate` abaixo; incluir os dois duplicaria a entrada.
    private static let relevantEventTypes: Set<HistoryEventType> = [.pairEdited, .pairTrashed, .pairRestored]

    static func build(
        pair: LensPair,
        allCleanings: [CaseCleaning],
        warningBelowPercent: Int,
        events: [HistoryEvent] = []
    ) -> [PairTimelineEntry] {
        var entries: [PairTimelineEntry] = []

        entries.append(PairTimelineEntry(
            id: "start-\(pair.id)",
            date: pair.startDate,
            kind: .start,
            title: "Par iniciado",
            subtitle: nil
        ))

        let ascendingUsages = (pair.usages ?? []).sorted { $0.date < $1.date }
        var crossedWarning = false
        for (index, usage) in ascendingUsages.enumerated() {
            let usageNumber = index + 1
            entries.append(PairTimelineEntry(
                id: "usage-\(usage.id)",
                date: usage.date,
                kind: .usage,
                title: "Uso nº \(usageNumber)",
                subtitle: usage.notes
            ))

            let remaining = max(0, pair.maximumUses - usageNumber)
            if !crossedWarning, pair.maximumUses > 0 {
                let remainingPercent = Int((Double(remaining) / Double(pair.maximumUses) * 100).rounded())
                if remainingPercent < warningBelowPercent {
                    crossedWarning = true
                    entries.append(PairTimelineEntry(
                        id: "warning-\(pair.id)",
                        date: usage.date,
                        kind: .warning,
                        title: "Restam \(remaining) utilizações",
                        subtitle: nil
                    ))
                }
            }
        }

        for session in (pair.wearSessions ?? []).sorted(by: { $0.startedAt < $1.startedAt }) {
            entries.append(PairTimelineEntry(
                id: "session-start-\(session.id)",
                date: session.startedAt,
                kind: .session,
                title: "Sessão iniciada",
                subtitle: nil
            ))
            if let endedAt = session.endedAt {
                entries.append(PairTimelineEntry(
                    id: "session-end-\(session.id)",
                    date: endedAt,
                    kind: .session,
                    title: "Sessão finalizada",
                    subtitle: "Duração: \(DateFormatting.durationShort(session.duration))"
                ))
            }
        }

        let periodEnd = pair.endDate ?? .distantFuture
        let cleaningsDuringPair = allCleanings
            .filter { $0.cleaningDate >= pair.startDate && $0.cleaningDate <= periodEnd }
            .sorted { $0.cleaningDate < $1.cleaningDate }
        for cleaning in cleaningsDuringPair {
            entries.append(PairTimelineEntry(
                id: "cleaning-\(cleaning.id)",
                date: cleaning.cleaningDate,
                kind: .cleaning,
                title: "Estojo limpo",
                subtitle: cleaning.notes
            ))
        }

        for event in events where event.lensPairID == pair.id && relevantEventTypes.contains(event.eventType) {
            entries.append(PairTimelineEntry(
                id: "event-\(event.id)",
                date: event.eventDate,
                kind: .edit,
                title: eventTitle(for: event.eventType),
                subtitle: event.descriptionText
            ))
        }

        if pair.status == .finished, let endDate = pair.endDate {
            let reason = pair.discardReasonValue?.displayName ?? "não informado"
            entries.append(PairTimelineEntry(
                id: "end-\(pair.id)",
                date: endDate,
                kind: .end,
                title: "Par substituído",
                subtitle: "Motivo: \(reason)"
            ))
        }

        return entries.sorted { $0.date < $1.date }
    }

    private static func eventTitle(for type: HistoryEventType) -> String {
        switch type {
        case .pairEdited: return "Par editado"
        case .pairTrashed: return "Par movido para a lixeira"
        case .pairRestored: return "Par restaurado da lixeira"
        default: return "Par atualizado"
        }
    }

    /// Agrupa entradas (já ordenadas cronologicamente, como `build(...)` sempre devolve) em
    /// baldes de mês/ano. Depende da entrada estar pré-ordenada — não reordena — para poder
    /// varrer uma vez só em vez de buscar o balde certo a cada entrada.
    static func groupedByMonth(_ entries: [PairTimelineEntry], calendar: Calendar = .current) -> [PairTimelineMonthGroup] {
        var buckets: [(components: DateComponents, entries: [PairTimelineEntry])] = []
        for entry in entries {
            let components = calendar.dateComponents([.year, .month], from: entry.date)
            if let lastIndex = buckets.indices.last, buckets[lastIndex].components == components {
                buckets[lastIndex].entries.append(entry)
            } else {
                buckets.append((components: components, entries: [entry]))
            }
        }
        return buckets.map { bucket in
            PairTimelineMonthGroup(
                id: "\(bucket.components.year ?? 0)-\(bucket.components.month ?? 0)",
                title: monthTitle(for: bucket.components, calendar: calendar),
                entries: bucket.entries
            )
        }
    }

    private static func monthTitle(for components: DateComponents, calendar: Calendar) -> String {
        guard let date = calendar.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM 'de' yyyy"
        let title = formatter.string(from: date)
        return title.prefix(1).uppercased() + title.dropFirst()
    }
}
