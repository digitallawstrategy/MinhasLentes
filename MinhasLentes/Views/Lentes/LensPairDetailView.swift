import SwiftUI

/// Tela de detalhe/estatísticas de um par — aberta ao tocar no card "Em uso" da Home ou pelo
/// deep link do widget. Não é a Linha do tempo (`PairTimelineView`, o log cronológico completo):
/// aqui é o retrato atual — vida útil, progresso, frequência, sessão de uso, produto — com um
/// botão explícito para a Linha do tempo quando o usuário quiser o histórico linha a linha.
struct LensPairDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pair: LensPair
    let settings: AppSettings
    let allCleanings: [CaseCleaning]
    let wearingSessionPairID: UUID?
    let onEdit: () -> Void

    @State private var showTimeline = false

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

    private var averageIntervalDays: Double? {
        LensStatisticsService.averageIntervalDays(betweenUsageDates: (pair.usages ?? []).map(\.date))
    }

    private var projectedDepletionDate: Date? {
        LensStatisticsService.projectedDepletionDate(usesRemaining: pair.usesRemaining, averageIntervalDays: averageIntervalDays)
    }

    private var averageSessionDuration: TimeInterval? {
        LensStatisticsService.averageSessionDuration(sessions: pair.wearSessions ?? [])
    }

    private var activeSession: WearSession? {
        (pair.wearSessions ?? []).first { $0.status == .active }
    }

    private var recentUsages: [LensUsage] {
        Array(pair.sortedUsages.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    lifeUsedCard
                    if let activeSession {
                        activeSessionCard(activeSession)
                    }
                    if !recentUsages.isEmpty {
                        historyCard
                    }
                    if pair.inventoryItem != nil {
                        productCard
                    }
                    SecondaryActionButton(title: "Ver linha do tempo", systemImage: "clock.arrow.circlepath") {
                        showTimeline = true
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, AppSpacing.sm)
            }
            .background(AmbientBackground())
            .navigationTitle(pair.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    // Fecha este sheet antes de sinalizar a edição — `onEdit` só marca a intenção
                    // no chamador, que abre o `EditPairSheet` depois que este terminar de fechar
                    // (ver comentário no `.sheet(item: $pairForDetail, ...)` de `LensPairsView`).
                    Button("Editar", systemImage: "pencil") {
                        onEdit()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTimeline) {
                PairTimelineView(pair: pair, settings: settings, allCleanings: allCleanings)
            }
        }
    }

    private var lifeUsedCard: some View {
        AppCard {
            SectionHeader("Vida útil")
            HStack(alignment: .top, spacing: AppSpacing.lg) {
                VStack(spacing: 2) {
                    UsageCountRing(value: pair.usesRemaining, remainingFraction: remainingFraction, tint: usageStatus.tone.color, diameter: 96, lineWidth: 12)
                    Text("\(pair.usesRemaining) restantes")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Usos restantes")
                .accessibilityValue("\(pair.usesRemaining) de \(pair.maximumUses)")

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    StatusBadge(text: usageStatus.label, tone: usageStatus.tone, systemImage: "shield.fill")
                    Text("\(pair.usesCount) de \(pair.maximumUses) usos registrados")
                        .font(AppTypography.headline)
                    Text("\(Int((remainingFraction * 100).rounded()))% da vida útil restante")
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressBarView(fraction: remainingFraction, tint: usageStatus.tone.color)
                .animation(reduceMotion ? nil : AppAnimation.standard, value: remainingFraction)
            if !lifeUsedStatItems.isEmpty {
                DetailStatGrid(items: lifeUsedStatItems)
            }
        }
    }

    private var lifeUsedStatItems: [DetailStatItem] {
        var items: [DetailStatItem] = []
        if let lastUsage = pair.lastUsageDate {
            items.append(DetailStatItem(label: "Último uso", value: DateFormatting.short.string(from: lastUsage)))
        }
        if let averageIntervalDays {
            items.append(DetailStatItem(label: "Frequência média", value: "a cada \(String(format: "%.1f", averageIntervalDays)) \(Pluralization.word(Int(averageIntervalDays.rounded()), "dia", "dias"))"))
        }
        if let projectedDepletionDate {
            items.append(DetailStatItem(label: "Previsão de término", value: DateFormatting.short.string(from: projectedDepletionDate)))
        }
        if let averageSessionDuration {
            items.append(DetailStatItem(label: "Duração média de uso", value: DateFormatting.durationShort(averageSessionDuration)))
        }
        return items
    }

    private func activeSessionCard(_ session: WearSession) -> some View {
        AppCard {
            SectionHeader("Sessão de uso")
            StatusBadge(text: "Em uso agora", tone: .informative, systemImage: "eye.circle.fill")
            DetailStatGrid(items: [
                DetailStatItem(label: "Duração atual", value: DateFormatting.durationShort(Date().timeIntervalSince(session.startedAt))),
            ])
        }
    }

    private var historyCard: some View {
        AppCard {
            SectionHeader("Últimos usos")
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(recentUsages, id: \.id) { usage in
                    HStack {
                        Text(DateFormatting.short.string(from: usage.date))
                            .font(AppTypography.subheadline)
                        Spacer()
                        Text(usage.side.displayName)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    if usage.id != recentUsages.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var productCard: some View {
        AppCard {
            SectionHeader("Produto")
            if let inventoryItem = pair.inventoryItem {
                DetailStatGrid(items: productStatItems(inventoryItem))
            }
        }
    }

    private func productStatItems(_ inventoryItem: LensInventoryItem) -> [DetailStatItem] {
        var items: [DetailStatItem] = [
            DetailStatItem(label: "Marca/modelo", value: "\(inventoryItem.brand) \(inventoryItem.model)"),
            DetailStatItem(label: "Lado", value: inventoryItem.side.displayName),
        ]
        if let expiryDate = inventoryItem.expiryDate {
            items.append(DetailStatItem(label: "Validade da caixa", value: DateFormatting.short.string(from: expiryDate)))
        }
        return items
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
    LensPairDetailView(pair: pair, settings: AppSettings(), allCleanings: [], wearingSessionPairID: nil, onEdit: {})
}
