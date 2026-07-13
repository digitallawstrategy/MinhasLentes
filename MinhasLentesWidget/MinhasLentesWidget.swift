import WidgetKit
import SwiftUI

struct LensEntry: TimelineEntry {
    let date: Date
    let snapshot: LensSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LensEntry {
        LensEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (LensEntry) -> Void) {
        completion(LensEntry(date: Date(), snapshot: context.isPreview ? .placeholder : LensSnapshotLoader.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LensEntry>) -> Void) {
        let entry = LensEntry(date: Date(), snapshot: LensSnapshotLoader.load())
        // Os dados só mudam quando o usuário interage com o app; atualizar a cada poucas horas
        // já mantém "dias desde a limpeza" e "próxima limpeza" corretos sem gastar orçamento
        // de atualização do sistema à toa.
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(4 * 3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct MinhasLentesWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if family == .systemSmall {
                SmallLensWidgetView(snapshot: entry.snapshot)
            } else {
                MediumLensWidgetView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(for: .widget) {
            WidgetGradient.background(colorScheme: colorScheme)
        }
        .widgetURL(deepLinkURL)
    }

    /// Toque no widget abre `LensPairDetailView` (vida útil, frequência, sessão de uso) do par em
    /// uso direto, sem passar pela Home genérica — só um destino por widget é suportado. Nunca
    /// abre o Diário/Linha do tempo: `AppRouter.openPair` + `LensPairsView.openPendingPairIfNeeded()`
    /// resolvem esta mesma URL para o detalhe, não para a linha do tempo (ver comentário lá).
    private var deepLinkURL: URL? {
        guard let pairID = entry.snapshot.pairID else { return nil }
        return URL(string: "minhaslentes://pair/\(pairID.uuidString)")
    }
}

private struct SmallLensWidgetView: View {
    let snapshot: LensSnapshot

    private var tone: Color {
        WidgetTone.forUsage(
            remaining: snapshot.usesRemaining, maximum: snapshot.maximumUses,
            goodBelowPercent: snapshot.healthGoodBelowPercent, warningBelowPercent: snapshot.healthWarningBelowPercent,
            criticalBelowPercent: snapshot.healthCriticalBelowPercent
        )
    }

    var body: some View {
        if snapshot.hasActivePair {
            // Um único ponto focal — o anel — com o nome do par e (só quando relevante) um
            // status compacto abaixo. Nada de segunda linha de legenda dentro do anel: o número
            // já é a informação, "restantes" é reforço de contexto fora dele, não obrigatório
            // quando já há uma sessão ativa para mostrar em cima disso.
            VStack(spacing: WidgetSpacing.xxs) {
                WidgetUsageRing(value: snapshot.usesRemaining, remainingFraction: snapshot.remainingFraction, tint: tone, diameter: 64, lineWidth: 7)
                Text(snapshot.pairName ?? "Par atual")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)
                if snapshot.wearingSince != nil {
                    Label("Em uso", systemImage: "eye.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WidgetColor.primary)
                        .labelStyle(.titleAndIcon)
                } else {
                    Text("restantes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyLensWidgetView(compact: true, debugMessage: snapshot.debugMessage)
        }
    }
}

private struct MediumLensWidgetView: View {
    let snapshot: LensSnapshot

    private var tone: Color {
        WidgetTone.forUsage(
            remaining: snapshot.usesRemaining, maximum: snapshot.maximumUses,
            goodBelowPercent: snapshot.healthGoodBelowPercent, warningBelowPercent: snapshot.healthWarningBelowPercent,
            criticalBelowPercent: snapshot.healthCriticalBelowPercent
        )
    }

    /// Dia mais urgente entre os 4 candidatos de "próximo cuidado" (limpeza do estojo, solução,
    /// substituição do estojo, consulta) — o widget só tem espaço para 1 desses por vez (3º sinal
    /// da lista priorizada), então mostra sempre o mais próximo/atrasado, nunca uma lista dos 4.
    private var mostUrgentCareSignal: WidgetSignalContent? {
        var candidates: [(days: Int, content: WidgetSignalContent)] = []
        if let days = snapshot.daysUntilNextCleaning {
            let text = days <= 0 ? "Limpeza do estojo atrasada" : "Limpeza do estojo em \(days)d"
            candidates.append((days, WidgetSignalContent(systemImage: "sparkles", text: text, isUrgent: days <= 0)))
        }
        if let days = snapshot.daysUntilSolutionDiscard {
            let text = days <= 0 ? "Solução vencida" : "Solução vence em \(days)d"
            candidates.append((days, WidgetSignalContent(systemImage: "drop.fill", text: text, isUrgent: days <= 0)))
        }
        if let days = snapshot.daysUntilCaseReplacement {
            let text = days <= 0 ? "Substituir estojo" : "Estojo em \(days)d"
            candidates.append((days, WidgetSignalContent(systemImage: "shippingbox.fill", text: text, isUrgent: days <= 0)))
        }
        if let days = snapshot.daysUntilNextAppointment {
            let text = "Consulta em \(days)d"
            candidates.append((days, WidgetSignalContent(systemImage: "calendar", text: text, isUrgent: false)))
        }
        return candidates.min { $0.days < $1.days }?.content
    }

    /// Até 3 sinais secundários, nesta ordem de prioridade — nunca mais que isso, para o widget
    /// não virar uma lista de labels do mesmo peso: (1) sessão de uso ativa, (2) cuidado diário
    /// pendente ou em dia, (3) o cuidado mais urgente entre limpeza/solução/estojo/consulta.
    private var secondarySignals: [WidgetSignalContent] {
        var signals: [WidgetSignalContent] = []
        if snapshot.wearingSince != nil {
            signals.append(WidgetSignalContent(systemImage: "eye.circle.fill", text: "Usando agora", isUrgent: false, tone: WidgetColor.primary))
        }
        signals.append(
            snapshot.hasRoutineCareToday
                ? WidgetSignalContent(systemImage: "checkmark.circle.fill", text: "Cuidado diário em dia", isUrgent: false, tone: WidgetColor.success)
                : WidgetSignalContent(systemImage: "sparkles", text: "Cuidado diário pendente", isUrgent: true)
        )
        if let mostUrgentCareSignal {
            signals.append(mostUrgentCareSignal)
        }
        return Array(signals.prefix(3))
    }

    var body: some View {
        if snapshot.hasActivePair {
            HStack(alignment: .center, spacing: WidgetSpacing.md) {
                // Zona esquerda: par atual.
                VStack(spacing: WidgetSpacing.xxs) {
                    WidgetUsageRing(value: snapshot.usesRemaining, remainingFraction: snapshot.remainingFraction, tint: tone, diameter: 66, lineWidth: 7)
                    Text(snapshot.pairName ?? "Par atual")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxHeight: .infinity)

                Divider()

                // Zona direita: até 3 sinais de cuidado, priorizados — nunca 5 labels soltos do
                // mesmo peso.
                VStack(alignment: .leading, spacing: WidgetSpacing.sm) {
                    ForEach(secondarySignals) { signal in
                        WidgetSignalRow(systemImage: signal.systemImage, text: signal.text, tone: signal.tone ?? (signal.isUrgent ? WidgetColor.warning : .secondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyLensWidgetView(compact: false, debugMessage: snapshot.debugMessage)
        }
    }
}

private struct WidgetSignalContent: Identifiable {
    let id = UUID()
    let systemImage: String
    let text: String
    var isUrgent: Bool = false
    var tone: Color?
}

private struct EmptyLensWidgetView: View {
    let compact: Bool
    let debugMessage: String?

    var body: some View {
        VStack(spacing: WidgetSpacing.xs) {
            Image(systemName: "eye.circle")
                .font(compact ? .title2 : .title)
                .foregroundStyle(WidgetColor.primary)
                .frame(width: compact ? 44 : 52, height: compact ? 44 : 52)
                .background(WidgetColor.primary.opacity(0.12), in: Circle())

            VStack(spacing: 2) {
                Text("Nenhum par em uso")
                    .font(.caption.weight(.semibold))
                Text("Abra o app para iniciar um ciclo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            #if DEBUG
            if let debugMessage {
                Text(debugMessage)
                    .font(.system(size: 8))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, compact ? WidgetSpacing.xs : WidgetSpacing.md)
    }
}

struct MinhasLentesWidget: Widget {
    let kind: String = "MinhasLentesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MinhasLentesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Minhas Lentes")
        .description("Acompanhe os usos restantes das suas lentes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    MinhasLentesWidget()
} timeline: {
    LensEntry(date: .now, snapshot: .placeholder)
    LensEntry(date: .now, snapshot: .empty)
}

#Preview(as: .systemMedium) {
    MinhasLentesWidget()
} timeline: {
    LensEntry(date: .now, snapshot: .placeholder)
    LensEntry(date: .now, snapshot: .empty)
}
