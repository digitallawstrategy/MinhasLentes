import SwiftUI

/// Cartão "Cuidados de hoje" do Início: o cuidado diário do estojo é a ação primária, sempre
/// visível; a limpeza periódica só aparece com destaque quando está perto do prazo, atrasada
/// ou nunca foi feita — fora dessa janela, vira só uma linha discreta. `RoutineCareLog` e
/// `CaseCleaning` continuam dois conceitos e dois botões separados (nunca misturados nos
/// dados), só a apresentação fica lado a lado por serem as duas ações mais comuns do dia.
struct TodayCareCardView: View {
    let lastRoutineCare: RoutineCareLog?
    /// Calculado pelo chamador a partir de todos os registros do dia, não só do mais recente —
    /// um registro futuro (ex.: engano em "Registrar em outro dia") ordenaria antes do de hoje
    /// e faria um cálculo local aqui perder o registro de hoje de vista.
    let hasRoutineCareToday: Bool
    let lastCleaning: CaseCleaning?
    let settings: AppSettings
    let onRegisterRoutineCareToday: () -> Void
    let onRegisterRoutineCareForOtherDay: () -> Void
    let onRegisterCleaningToday: () -> Void

    private var nextCleaningDate: Date? {
        guard let lastCleaning else { return nil }
        return LensStatisticsService.nextCleaningDate(
            lastCleaningDate: lastCleaning.cleaningDate,
            intervalDays: settings.cleaningIntervalDays
        )
    }

    private var daysUntilNextCleaning: Int? {
        guard let nextCleaningDate else { return nil }
        return LensStatisticsService.daysUntil(nextCleaningDate)
    }

    /// Sem nenhuma limpeza registrada ainda, vale a pena sugerir a primeira; daí em diante só
    /// quando estiver perto do prazo (mesma janela do aviso antecipado) ou atrasada.
    private var isCleaningDue: Bool {
        guard let daysUntilNextCleaning else { return true }
        return daysUntilNextCleaning <= settings.advanceReminderDays
    }

    private var cleaningTone: AppStatusTone {
        guard let daysUntilNextCleaning else { return .informative }
        if daysUntilNextCleaning <= 0 { return .critical }
        if daysUntilNextCleaning <= settings.advanceReminderDays { return .warning }
        return .success
    }

    var body: some View {
        AppCard {
            SectionHeader("Cuidados de hoje", leadingIcon: "calendar.badge.checkmark") {
                if hasRoutineCareToday && !isCleaningDue {
                    StatusBadge(text: "Em dia", tone: .success, systemImage: "checkmark.circle.fill")
                }
            }
            routineCareSection
            if isCleaningDue {
                Divider()
                dueCleaningSection
            } else if let daysUntilNextCleaning {
                Text("Próxima limpeza periódica em \(daysUntilNextCleaning) dia(s)")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var routineCareSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Rótulo em cima do valor, não lado a lado como o `StatRow` genérico usa — "Último
            // cuidado diário" mais uma data com hora não cabem confortavelmente numa linha só em
            // tela estreita ou Dynamic Type maior, e espremer os dois nunca é aceitável aqui.
            VStack(alignment: .leading, spacing: 2) {
                Text("Último cuidado diário")
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
                Text(lastRoutineCare.map { DateFormatting.shortWithTime.string(from: $0.date) } ?? "Nenhum registrado")
                    .font(AppTypography.subheadlineMedium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if hasRoutineCareToday {
                StatusBadge(text: "Cuidado diário já registrado hoje", tone: .success, systemImage: "checkmark.circle.fill", fullWidth: true)
                // Única ação restante nesta seção quando o cuidado diário já foi registrado —
                // ganha o mesmo destaque preenchido que "Retirei as lentes" ganha no cartão "Em
                // uso" pelo mesmo motivo.
                PrimaryActionButton(title: "Registrar em outro dia", systemImage: "calendar.badge.checkmark", action: onRegisterRoutineCareForOtherDay)
            } else {
                PrimaryActionButton(title: "Registrar cuidado diário", systemImage: "drop.circle", action: onRegisterRoutineCareToday)
                SecondaryActionButton(title: "Registrar em outro dia", systemImage: "calendar.badge.checkmark", action: onRegisterRoutineCareForOtherDay)
                    .controlSize(.small)
            }
        }
    }

    private var dueCleaningSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(cleaningSituationText)
                .font(AppTypography.footnote.weight(.medium))
                .foregroundStyle(cleaningTone.color)
            PrimaryActionButton(title: "Registrar limpeza periódica", systemImage: "sparkles", action: onRegisterCleaningToday)
        }
    }

    private var cleaningSituationText: String {
        guard let daysUntilNextCleaning else { return "Nenhuma limpeza periódica registrada ainda" }
        return daysUntilNextCleaning <= 0 ? "Limpeza periódica atrasada" : "Limpeza periódica prevista em \(daysUntilNextCleaning) dia(s)"
    }
}

#Preview {
    TodayCareCardView(
        lastRoutineCare: nil,
        hasRoutineCareToday: false,
        lastCleaning: nil,
        settings: AppSettings(),
        onRegisterRoutineCareToday: {},
        onRegisterRoutineCareForOtherDay: {},
        onRegisterCleaningToday: {}
    )
    .padding()
}
