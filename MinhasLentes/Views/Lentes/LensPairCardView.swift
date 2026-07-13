import SwiftUI

/// Cartão-dashboard do par em uso: identificação, anel de progresso, status de utilização e
/// detalhes de uso (frequência média, projeção de término, duração média de sessão). O registro
/// rápido de "uso hoje" e a sessão "estou usando as lentes" moram na aba Início — aqui é onde
/// se olha o detalhe do par e se faz a gestão dele (editar, mover para reserva, encerrar,
/// lixeira). O emblema "Em uso agora" é só informativo, não uma ação.
struct LensPairCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let pair: LensPair
    let settings: AppSettings
    let onFinishPair: () -> Void
    let onEdit: () -> Void
    let onShowDiary: () -> Void
    let onMoveToTrash: () -> Void
    let onDemoteToReserve: () -> Void
    let wearingSessionPairID: UUID?

    @State private var showTrashConfirmation = false

    private var isWearingSessionActiveHere: Bool {
        wearingSessionPairID == pair.id
    }

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

    var body: some View {
        AppCard {
            header
            ringAndHeadline
            ProgressBarView(fraction: remainingFraction, tint: usageStatus.tone.color)
                .animation(reduceMotion ? nil : AppAnimation.standard, value: remainingFraction)
            detailStats
        }
        .alert("Mover \(pair.name) para a lixeira?", isPresented: $showTrashConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Mover para a lixeira", role: .destructive, action: onMoveToTrash)
        } message: {
            Text("Some da Home e das reservas, mas fica recuperável na Lixeira (Mais → Dados) por \(LensPairService.trashRetentionDays) dias.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(pair.name)
                    .font(.title3.weight(.semibold))
                Text("Iniciado em \(DateFormatting.short.string(from: pair.startDate))")
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
                badges
            }
            Spacer()
            Menu {
                Button("Editar par", systemImage: "pencil", action: onEdit)
                Button("Ver diário do par", systemImage: "book.pages", action: onShowDiary)
                Button("Mover para reserva", systemImage: "tray.and.arrow.down", action: onDemoteToReserve)
                Button("Encerrar ou substituir este par", systemImage: "arrow.triangle.2.circlepath", role: .destructive, action: onFinishPair)
                Button("Mover para a lixeira", systemImage: "trash", role: .destructive) {
                    showTrashConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Mais opções para \(pair.name)")
        }
    }

    /// Em tamanhos normais os dois selos cabem lado a lado, compactos. Em accessibility sizes,
    /// "Vida útil alta" + "Em uso agora" juntos não cabem na largura do cartão — dividir a linha
    /// truncava ambos ("Vi…"/"Em…"). Empilhados, cada um fica sozinho na própria linha e pode usar
    /// `lineLimit: nil` (mesmo padrão de `StatusBadge`: quebra em 2+ linhas dentro da pílula em
    /// vez de truncar).
    @ViewBuilder
    private var badges: some View {
        let usageBadge = StatusBadge(
            text: usageStatus.label,
            tone: usageStatus.tone,
            systemImage: "shield.fill",
            lineLimit: dynamicTypeSize.isAccessibilitySize ? nil : 1
        )
        let wearingBadge = isWearingSessionActiveHere ? StatusBadge(
            text: "Em uso agora",
            tone: .informative,
            systemImage: "eye.circle.fill",
            lineLimit: dynamicTypeSize.isAccessibilitySize ? nil : 1
        ) : nil

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                usageBadge
                wearingBadge
            }
        } else {
            HStack(spacing: AppSpacing.xs) {
                usageBadge
                wearingBadge
            }
        }
    }

    /// `ViewThatFits` alterna para o layout vertical (anel centralizado acima do texto) quando o
    /// horizontal não cabe — nome de par longo, Dynamic Type grande e telas estreitas combinados
    /// podiam comprimir ou cortar a coluna de texto no layout único anterior.
    private var ringAndHeadline: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.lg) {
                ringView
                usageHeadlineText(alignment: .leading)
                Spacer()
            }
            VStack(spacing: AppSpacing.sm) {
                ringView
                usageHeadlineText(alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var ringView: some View {
        VStack(spacing: 2) {
            UsageCountRing(value: pair.usesRemaining, remainingFraction: remainingFraction, tint: usageStatus.tone.color, diameter: 108, lineWidth: 14)
            // O número dentro do anel é decorativo (tamanho fixo); esta legenda é o texto real,
            // por extenso, que escala com Dynamic Type — repete o valor para continuar completa
            // mesmo se só ela for lida.
            Text("\(pair.usesRemaining) restantes")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Usos restantes")
        .accessibilityValue("\(pair.usesRemaining) de \(pair.maximumUses)")
    }

    private func usageHeadlineText(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: AppSpacing.xxs) {
            Text("\(pair.usesCount) de \(pair.maximumUses) usos registrados")
                .font(AppTypography.headline)
            Text("\(Int((remainingFraction * 100).rounded()))% da vida útil restante")
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // Antes, até 4 StatRow empilhadas — rótulo e valor no mesmo peso, uma embaixo da outra, lendo
    // como uma planilha. `DetailStatGrid` (mesmo espírito do "Highlights" da Apple Saúde) deixa
    // mais óbvio que são fatos secundários, não uma lista de igual importância ao anel/status
    // acima.
    private var detailStatItems: [DetailStatItem] {
        var items: [DetailStatItem] = []
        // Só existe quando o par foi iniciado a partir de uma caixa do estoque (ver
        // `LensPair.inventoryItem`) — pares antigos ou iniciados sem estoque simplesmente não
        // mostram esta linha, sem quebra visual.
        if let inventoryItem = pair.inventoryItem {
            items.append(DetailStatItem(label: "Produto", value: "\(inventoryItem.brand) \(inventoryItem.model)"))
            if let expiryDate = inventoryItem.expiryDate {
                items.append(DetailStatItem(label: "Validade da caixa", value: DateFormatting.short.string(from: expiryDate)))
            }
        }
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

    @ViewBuilder
    private var detailStats: some View {
        if !detailStatItems.isEmpty {
            DetailStatGrid(items: detailStatItems)
        }
    }
}
