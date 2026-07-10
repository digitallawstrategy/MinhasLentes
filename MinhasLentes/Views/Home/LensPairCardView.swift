import SwiftUI

/// Cartão do par atual: identificação, estatísticas de uso, ciclo do estojo e o botão
/// principal "Registrar uso hoje".
struct LensPairCardView: View {
    let pair: LensPair
    let lastCleaning: CaseCleaning?
    let settings: AppSettings
    let onRegisterUsage: () -> Void
    let onFinishPair: () -> Void
    let onRename: (String) -> Void

    @State private var isRenaming = false
    @State private var newName = ""

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
            VStack(alignment: .leading, spacing: 14) {
                header
                ProgressBarView(fraction: pair.lifeUsedFraction)
                stats
                registerButton
            }
        }
        .alert("Renomear par", isPresented: $isRenaming) {
            TextField("Nome do par", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") {
                onRename(newName)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pair.name)
                    .font(.title3.weight(.semibold))
                Text("Iniciado em \(DateFormatting.short.string(from: pair.startDate))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Renomear par") {
                    newName = pair.name
                    isRenaming = true
                }
                Button("Encerrar ou substituir este par", role: .destructive, action: onFinishPair)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Mais opções para \(pair.name)")
        }
    }

    private var stats: some View {
        VStack(spacing: 6) {
            StatRow(label: "Usos realizados", value: "\(pair.usesCount) de \(pair.maximumUses)")
            StatRow(label: "Usos restantes", value: "\(pair.usesRemaining)")
            StatRow(label: "Vida útil utilizada", value: "\(Int((pair.lifeUsedFraction * 100).rounded()))%")
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
}
