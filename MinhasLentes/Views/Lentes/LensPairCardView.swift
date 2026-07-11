import SwiftUI

/// Cartão-dashboard do par em uso: identificação, anel de progresso, status de utilização e
/// detalhes de uso (frequência média, projeção de término, duração média de sessão). O registro
/// rápido de "uso hoje" e a sessão "estou usando as lentes" moram na aba Início — aqui é onde
/// se olha o detalhe do par e se faz a gestão dele (editar, mover para reserva, encerrar,
/// lixeira). O emblema "Em uso agora" é só informativo, não uma ação.
struct LensPairCardView: View {
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
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                header
                ringAndHeadline
                ProgressBarView(fraction: remainingFraction, tint: usageStatus.tintColor)
                    .animation(.easeInOut(duration: 0.6), value: remainingFraction)
                detailStats
            }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(pair.name)
                    .font(.title3.weight(.semibold))
                Text("Iniciado em \(DateFormatting.short.string(from: pair.startDate))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    UsageStatusBadgeView(status: usageStatus)
                    if isWearingSessionActiveHere {
                        Label("Em uso agora", systemImage: "eye.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
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

    private var ringAndHeadline: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRingView(remainingFraction: remainingFraction, tint: usageStatus.tintColor)
                VStack(spacing: 0) {
                    Text("\(pair.usesRemaining)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText(value: Double(pair.usesRemaining)))
                        .animation(.spring(duration: 0.5), value: pair.usesRemaining)
                    Text("restantes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 108, height: 108)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Usos restantes")
            .accessibilityValue("\(pair.usesRemaining) de \(pair.maximumUses)")

            VStack(alignment: .leading, spacing: 6) {
                Text("\(pair.usesCount) de \(pair.maximumUses) usos")
                    .font(.headline)
                Text("\(Int((remainingFraction * 100).rounded()))% do limite de utilizações restante")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var detailStats: some View {
        if let lastUsage = pair.lastUsageDate {
            StatRow(label: "Último uso", value: DateFormatting.short.string(from: lastUsage))
        }
        if let averageIntervalDays {
            StatRow(label: "Frequência média", value: "a cada \(String(format: "%.1f", averageIntervalDays)) dia(s)")
        }
        if let projectedDepletionDate {
            StatRow(label: "Previsão de término", value: DateFormatting.short.string(from: projectedDepletionDate))
        }
        if let averageSessionDuration {
            StatRow(label: "Duração média de uso", value: DateFormatting.durationShort(averageSessionDuration))
        }
    }
}
