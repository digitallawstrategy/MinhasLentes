import SwiftUI
import SwiftData

/// Categoria de filtro da linha do tempo — seleção única, diferente de `HistoryFilter`
/// (`Views/History/HistoryFilterBar.swift`), que é multi-seleção para filtros combináveis por
/// tipo+lado no Histórico geral. Aqui as 4 categorias são mutuamente exclusivas na cabeça do
/// usuário, então um `Set` seria over-engineering.
enum PairTimelineFilter: String, CaseIterable, Identifiable {
    case all, usage, session, cleaning, event

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "Todos"
        case .usage: return "Usos"
        case .session: return "Sessões"
        case .cleaning: return "Cuidados"
        case .event: return "Eventos"
        }
    }

    func matches(_ kind: PairTimelineEntryKind) -> Bool {
        switch self {
        case .all: return true
        case .usage: return kind == .usage || kind == .warning
        case .session: return kind == .session
        case .cleaning: return kind == .cleaning
        case .event: return kind == .start || kind == .edit || kind == .end
        }
    }
}

/// Linha do tempo de um par — a auditoria cronológica completa: "o que aconteceu com este par ao
/// longo do tempo?" Não é o retrato de hoje (isso é `LensPairDetailView`, o destino principal ao
/// tocar num par) — esta tela é sempre secundária, aberta por um botão/menu explícito.
struct PairTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \HistoryEvent.eventDate) private var allEvents: [HistoryEvent]

    let pair: LensPair
    let settings: AppSettings
    let allCleanings: [CaseCleaning]

    @State private var activeFilter: PairTimelineFilter = .all

    private var remainingFraction: Double {
        guard pair.maximumUses > 0 else { return 0 }
        return Double(pair.usesRemaining) / Double(pair.maximumUses)
    }

    private var usageStatus: LensUsageStatus {
        LensStatisticsService.usageStatus(
            usesRemaining: pair.usesRemaining,
            maximumUses: pair.maximumUses,
            goodBelowPercent: settings.healthGoodBelowPercent,
            warningBelowPercent: settings.healthWarningBelowPercent,
            criticalBelowPercent: settings.healthCriticalBelowPercent
        )
    }

    private var pairEvents: [HistoryEvent] {
        allEvents.filter { $0.lensPairID == pair.id }
    }

    private var allEntries: [PairTimelineEntry] {
        PairTimelineBuilder.build(
            pair: pair, allCleanings: allCleanings, warningBelowPercent: settings.healthWarningBelowPercent, events: pairEvents
        )
    }

    private var filteredEntries: [PairTimelineEntry] {
        allEntries.filter { activeFilter.matches($0.kind) }
    }

    private var groupedEntries: [PairTimelineMonthGroup] {
        PairTimelineBuilder.groupedByMonth(filteredEntries)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    header
                    filterBar
                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedEntries) { group in
                            monthCard(group)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, AppSpacing.sm)
                .animation(reduceMotion ? nil : AppAnimation.standard, value: activeFilter)
            }
            .background(AmbientBackground())
            .navigationTitle("Linha do tempo — \(pair.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    // MARK: - Cabeçalho

    private var header: some View {
        AppCard {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    headerRing
                    headerText
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    headerRing
                    headerText
                }
            }
        }
    }

    private var headerRing: some View {
        UsageCountRing(value: pair.usesRemaining, remainingFraction: remainingFraction, tint: usageStatus.tone.color, diameter: 64, lineWidth: 8)
            .accessibilityHidden(true)
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(pair.name)
                .font(AppTypography.headline)
            StatusBadge(text: usageStatus.label, tone: usageStatus.tone, systemImage: "shield.fill", lineLimit: dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text("Iniciado em \(DateFormatting.short.string(from: pair.startDate)) · \(pair.usesRemaining) de \(pair.maximumUses) usos restantes")
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
            if let inventoryItem = pair.inventoryItem {
                Text("\(inventoryItem.brand) \(inventoryItem.model)")
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Filtro

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(PairTimelineFilter.allCases) { filter in
                    filterChip(filter)
                }
            }
        }
    }

    private func filterChip(_ filter: PairTimelineFilter) -> some View {
        let isActive = filter == activeFilter
        return Button {
            activeFilter = filter
        } label: {
            Text(filter.displayName)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs)
                .background(Capsule().fill(isActive ? AppColor.primary : Color.secondary.opacity(0.15)))
                .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    // MARK: - Estado vazio

    private var emptyState: some View {
        EmptyStateView(
            title: activeFilter == .all ? "Nenhum evento ainda" : "Nada nesta categoria",
            systemImage: "clock",
            description: activeFilter == .all
                ? "Os eventos deste par vão aparecer aqui conforme forem acontecendo."
                : "Não há eventos de \"\(activeFilter.displayName)\" registrados para este par."
        )
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - Linhas

    private func monthCard(_ group: PairTimelineMonthGroup) -> some View {
        AppCard {
            SectionHeader(group.title)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(group.entries) { entry in
                    timelineRow(entry)
                    if entry.id != group.entries.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func timelineRow(_ entry: PairTimelineEntry) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon(for: entry.kind))
                .font(.footnote)
                .foregroundStyle(tone(for: entry.kind).color)
                .frame(width: 30, height: 30)
                .background(tone(for: entry.kind).color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(AppTypography.subheadline.weight(.semibold))
                Text(DateFormatting.shortWithTime.string(from: entry.date))
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func icon(for kind: PairTimelineEntryKind) -> String {
        switch kind {
        case .start: return "calendar"
        case .usage: return "eye"
        case .warning: return "exclamationmark.triangle"
        case .session: return "timer"
        case .cleaning: return "sparkles"
        case .edit: return "pencil"
        case .end: return "arrow.triangle.2.circlepath"
        }
    }

    private func tone(for kind: PairTimelineEntryKind) -> AppStatusTone {
        kind == .warning ? .warning : .informative
    }
}

#Preview {
    let pair = LensPair(
        name: "Par nº 1",
        sequenceNumber: 1,
        startDate: Date(),
        maximumUses: 60,
        trackingMode: .pair,
        side: .both
    )
    PairTimelineView(pair: pair, settings: AppSettings(), allCleanings: [])
        .modelContainer(PreviewData.container)
}
