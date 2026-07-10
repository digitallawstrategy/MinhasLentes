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

    var body: some View {
        Group {
            if family == .systemSmall {
                SmallLensWidgetView(snapshot: entry.snapshot)
            } else {
                MediumLensWidgetView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(deepLinkURL)
    }

    /// Toque no widget abre o Diário do par em uso direto, sem passar pela Home genérica —
    /// só um destino por widget é suportado, então isso é tudo que dá pra linkar aqui.
    private var deepLinkURL: URL? {
        guard let pairID = entry.snapshot.pairID else { return nil }
        return URL(string: "minhaslentes://pair/\(pairID.uuidString)")
    }
}

private struct SmallLensWidgetView: View {
    let snapshot: LensSnapshot

    var body: some View {
        if snapshot.hasActivePair {
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                Text("\(snapshot.usesRemaining)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("usos restantes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            EmptyLensWidgetView(compact: true, debugMessage: snapshot.debugMessage)
        }
    }
}

private struct MediumLensWidgetView: View {
    let snapshot: LensSnapshot

    var body: some View {
        if snapshot.hasActivePair {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.pairName ?? "Par atual")
                        .font(.headline)
                    Text("\(snapshot.usesRemaining) usos restantes")
                        .font(.subheadline.weight(.semibold))
                    Text("\(snapshot.usesCount) de \(snapshot.maximumUses) usados")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let daysSinceCleaning = snapshot.daysSinceCleaning {
                        Label("Estojo limpo há \(daysSinceCleaning)d", systemImage: "sparkles")
                    }
                    if let daysUntilNextCleaning = snapshot.daysUntilNextCleaning {
                        Label(
                            daysUntilNextCleaning <= 0 ? "Limpeza atrasada" : "Limpeza em \(daysUntilNextCleaning)d",
                            systemImage: "calendar"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            EmptyLensWidgetView(compact: false, debugMessage: snapshot.debugMessage)
        }
    }
}

private struct EmptyLensWidgetView: View {
    let compact: Bool
    let debugMessage: String?

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "eye.slash")
                .font(.title2)
            Text(compact ? "Nenhum par ativo" : "Nenhum par ativo — abra o app para começar")
                .font(.caption)
                .multilineTextAlignment(.center)
            #if DEBUG
            if let debugMessage {
                Text(debugMessage)
                    .font(.system(size: 8))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            #endif
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
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
