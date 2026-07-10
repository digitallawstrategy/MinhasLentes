import SwiftUI

/// Cartão compacto do estojo na Home: só o essencial (última limpeza, contagem regressiva) e
/// a ação rápida de registrar a limpeza de hoje. Informação do estojo pertence ao estojo, não
/// a cada par — por isso mora aqui uma vez só, em vez de repetida em cada cartão de par.
struct CaseSummaryCardView: View {
    let lastCleaning: CaseCleaning?
    let settings: AppSettings
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

    private var countdownFraction: Double {
        guard let daysUntilNextCleaning, settings.cleaningIntervalDays > 0 else { return 0 }
        return min(max(Double(daysUntilNextCleaning) / Double(settings.cleaningIntervalDays), 0), 1)
    }

    private var countdownTint: Color {
        guard let daysUntilNextCleaning else { return .accentColor }
        if daysUntilNextCleaning <= 0 { return .red }
        if daysUntilNextCleaning <= settings.advanceReminderDays { return .orange }
        return .green
    }

    var body: some View {
        SectionCard(title: "Estojo") {
            VStack(alignment: .leading, spacing: 10) {
                if let lastCleaning {
                    StatRow(label: "Última limpeza", value: DateFormatting.short.string(from: lastCleaning.cleaningDate))
                } else {
                    StatRow(label: "Última limpeza", value: "Nenhuma registrada")
                }
                if let daysUntilNextCleaning {
                    Text(daysUntilNextCleaning <= 0 ? "Limpeza atrasada" : "Faltam \(daysUntilNextCleaning) dia(s)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(countdownTint)
                    ProgressBarView(fraction: countdownFraction, tint: countdownTint)
                        .animation(.easeInOut(duration: 0.6), value: countdownFraction)
                }
                Button(action: onRegisterCleaningToday) {
                    Label("Limpei o estojo hoje", systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    CaseSummaryCardView(lastCleaning: nil, settings: AppSettings(), onRegisterCleaningToday: {})
        .padding()
}
