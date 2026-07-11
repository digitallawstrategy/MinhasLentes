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

    private var countdownTint: Color {
        guard let daysUntilNextCleaning else { return .accentColor }
        if daysUntilNextCleaning <= 0 { return .red }
        if daysUntilNextCleaning <= settings.advanceReminderDays { return .orange }
        return .green
    }

    var body: some View {
        SectionCard(title: "Cuidados de hoje") {
            VStack(alignment: .leading, spacing: 12) {
                routineCareSection
                if isCleaningDue {
                    Divider()
                    dueCleaningSection
                } else if let daysUntilNextCleaning {
                    Text("Próxima limpeza periódica em \(daysUntilNextCleaning) dia(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var routineCareSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lastRoutineCare {
                StatRow(label: "Último cuidado diário", value: DateFormatting.shortWithTime.string(from: lastRoutineCare.date))
            } else {
                StatRow(label: "Último cuidado diário", value: "Nenhum registrado")
            }
            if hasRoutineCareToday {
                Label("Cuidado diário já registrado hoje", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button(action: onRegisterRoutineCareToday) {
                    Label("Registrar cuidado diário", systemImage: "drop.circle")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Registrar em outro dia", action: onRegisterRoutineCareForOtherDay)
                .font(.caption)
        }
    }

    private var dueCleaningSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let daysUntilNextCleaning {
                Text(daysUntilNextCleaning <= 0 ? "Limpeza periódica atrasada" : "Limpeza periódica prevista em \(daysUntilNextCleaning) dia(s)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(countdownTint)
            } else {
                Text("Nenhuma limpeza periódica registrada ainda")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Button(action: onRegisterCleaningToday) {
                Label("Registrar limpeza periódica", systemImage: "sparkles")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
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
