import SwiftUI

/// Cartão-dashboard do par em uso: identificação, anel de progresso, status de utilização,
/// estatísticas e o botão principal "Registrar uso hoje". Pensado para que a situação das
/// lentes seja compreendida em poucos segundos.
struct LensPairCardView: View {
    let pair: LensPair
    let lastCleaning: CaseCleaning?
    let settings: AppSettings
    let onRegisterUsage: () -> Void
    let onFinishPair: () -> Void
    let onEdit: () -> Void
    let onShowDiary: () -> Void
    let onDelete: () -> Void
    let onDemoteToReserve: () -> Void
    let wearingSessionPairID: UUID?
    let onToggleWearingSession: () -> Void

    @State private var showDeleteConfirmation = false

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

    private var nextCleaningDate: Date? {
        guard let lastCleaning else { return nil }
        return LensStatisticsService.nextCleaningDate(
            lastCleaningDate: lastCleaning.cleaningDate,
            intervalDays: settings.cleaningIntervalDays
        )
    }

    private var advanceReminderDate: Date? {
        guard let lastCleaning else { return nil }
        return LensStatisticsService.advanceReminderDate(
            lastCleaningDate: lastCleaning.cleaningDate,
            intervalDays: settings.cleaningIntervalDays,
            advanceDays: settings.advanceReminderDays
        )
    }

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                header
                ringAndHeadline
                ProgressBarView(fraction: remainingFraction, tint: usageStatus.tintColor)
                    .animation(.easeInOut(duration: 0.6), value: remainingFraction)
                stats
                registerButton
                if wearingSessionPairID == nil || isWearingSessionActiveHere {
                    wearingSessionButton
                }
            }
        }
        .alert("Excluir \(pair.name)?", isPresented: $showDeleteConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir permanentemente", role: .destructive, action: onDelete)
        } message: {
            Text("Isso apaga o par e os \(pair.usesCount) uso(s) registrados nele. Diferente de encerrar, não pode ser desfeito.")
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
                UsageStatusBadgeView(status: usageStatus)
            }
            Spacer()
            Menu {
                Button("Editar par", systemImage: "pencil", action: onEdit)
                Button("Ver diário do par", systemImage: "book.pages", action: onShowDiary)
                Button("Mover para reserva", systemImage: "tray.and.arrow.down", action: onDemoteToReserve)
                Button("Encerrar ou substituir este par", systemImage: "arrow.triangle.2.circlepath", role: .destructive, action: onFinishPair)
                Button("Excluir par", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
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
                Text("\(Int((remainingFraction * 100).rounded()))% da vida útil restante")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var stats: some View {
        VStack(spacing: 6) {
            if let lastUsage = pair.lastUsageDate {
                StatRow(label: "Último uso", value: DateFormatting.short.string(from: lastUsage))
            }
            if let lastCleaning {
                StatRow(label: "Última limpeza do estojo", value: DateFormatting.short.string(from: lastCleaning.cleaningDate))
            }
            if let advanceReminderDate {
                StatRow(label: "Aviso antecipado", value: DateFormatting.short.string(from: advanceReminderDate))
            }
            if let nextCleaningDate {
                StatRow(label: "Próxima limpeza", value: DateFormatting.short.string(from: nextCleaningDate))
            }
        }
    }

    private var registerButton: some View {
        Button(action: onRegisterUsage) {
            Label("Registrar uso hoje", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(pair.hasReachedLimit)
        .accessibilityHint(pair.hasReachedLimit ? "Limite de usos atingido" : "Registra uma utilização na data de hoje")
    }

    private var wearingSessionButton: some View {
        Button(action: onToggleWearingSession) {
            Label(
                isWearingSessionActiveHere ? "Parar sessão de uso" : "Estou usando as lentes",
                systemImage: isWearingSessionActiveHere ? "stop.circle" : "eye.circle"
            )
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(isWearingSessionActiveHere ? .red : .accentColor)
        .accessibilityHint(
            isWearingSessionActiveHere
                ? "Encerra a Live Activity e o lembrete de remoção"
                : "Inicia uma Live Activity e agenda um lembrete para remover as lentes depois de algumas horas"
        )
    }
}
