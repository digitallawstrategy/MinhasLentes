import Foundation
import SwiftData

/// Configurações do aplicativo. Deve existir uma única instância persistida — use
/// `AppSettingsStore` (Services) para obter ou criar essa instância com segurança.
@Model
final class AppSettings {
    var id: UUID = UUID()
    var maximumUses: Int = 60
    var cleaningIntervalDays: Int = 15
    var advanceReminderDays: Int = 3
    var notificationHour: Int = 9
    var notificationMinute: Int = 0
    var allowMultipleUsesPerDay: Bool = false
    var advanceReminderEnabled: Bool = true
    var deadlineReminderEnabled: Bool = true
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    var trackingModeRawValue: String = TrackingMode.pair.rawValue

    /// Faixas do status de UTILIZAÇÃO configuráveis (leitura da contagem de usos restantes,
    /// não uma avaliação clínica), expressas em percentual (0...100). Abaixo de
    /// `healthGoodBelowPercent` o par deixa de ter "Vida útil alta"; abaixo de
    /// `healthWarningBelowPercent`, vira "Poucos usos restantes"; abaixo de
    /// `healthCriticalBelowPercent`, vira "Limite de usos atingido". Os nomes dos campos
    /// ficaram como estavam para não exigir migração de dados já salvos.
    var healthGoodBelowPercent: Int = 80
    var healthWarningBelowPercent: Int = 40
    var healthCriticalBelowPercent: Int = 15

    /// Após quantas horas de sessão "Estou usando as lentes" o uso passa a ser considerado
    /// excessivo — dispara o primeiro de três lembretes progressivos (este valor, +1h, +2h).
    var wearingReminderHours: Int = 8
    /// De quantas em quantas horas o lembrete se repete depois do terceiro aviso progressivo,
    /// enquanto a sessão continuar ativa.
    var wearingExcessiveRepeatIntervalHours: Int = 1

    /// Intervalo recomendado, em dias, para substituição do estojo físico. Copiado para cada
    /// `LensCase` no momento em que o ciclo começa — mudar aqui não altera ciclos já iniciados.
    var caseReplacementIntervalDays: Int = 90
    /// Liga/desliga todo o conjunto de avisos de substituição do estojo (15 dias antes, 7 dias
    /// antes, no dia e o lembrete periódico após o prazo).
    var caseReminderEnabled: Bool = true
    /// De quantos em quantos dias o lembrete se repete depois que o prazo recomendado já passou
    /// e nenhuma substituição foi registrada.
    var caseOverdueReminderIntervalDays: Int = 7

    /// Liga/desliga os avisos de validade da solução de limpeza (30 e 7 dias antes, no dia do
    /// descarte recomendado e o lembrete periódico após o prazo).
    var solutionReminderEnabled: Bool = true
    /// De quantos em quantos dias o lembrete de troca da solução se repete depois que o prazo
    /// recomendado já passou e nenhuma troca foi registrada.
    var solutionOverdueReminderIntervalDays: Int = 7

    /// Liga/desliga os avisos de validade dos itens em estoque (60/30/7 dias antes e no dia).
    var inventoryReminderEnabled: Bool = true

    /// Liga/desliga os lembretes de consulta (30/7/1 dias antes e 2 horas antes).
    var appointmentReminderEnabled: Bool = true
    /// Prazo padrão até a próxima consulta, em meses — copiado para cada `EyeAppointment` no
    /// momento do agendamento, ajustável por consulta.
    var defaultAppointmentIntervalMonths: Int = 12

    init(id: UUID = UUID()) {
        self.id = id
    }

    var trackingMode: TrackingMode {
        get { TrackingMode(rawValue: trackingModeRawValue) ?? .pair }
        set { trackingModeRawValue = newValue.rawValue }
    }

    /// Restaura os valores padrão de fábrica (usado em "Restaurar configurações padrão").
    func restoreDefaults() {
        maximumUses = 60
        cleaningIntervalDays = 15
        advanceReminderDays = 3
        notificationHour = 9
        notificationMinute = 0
        allowMultipleUsesPerDay = false
        advanceReminderEnabled = true
        deadlineReminderEnabled = true
        soundEnabled = true
        badgeEnabled = true
        trackingModeRawValue = TrackingMode.pair.rawValue
        healthGoodBelowPercent = 80
        healthWarningBelowPercent = 40
        healthCriticalBelowPercent = 15
        wearingReminderHours = 8
        wearingExcessiveRepeatIntervalHours = 1
        caseReplacementIntervalDays = 90
        caseReminderEnabled = true
        caseOverdueReminderIntervalDays = 7
        solutionReminderEnabled = true
        solutionOverdueReminderIntervalDays = 7
        inventoryReminderEnabled = true
        appointmentReminderEnabled = true
        defaultAppointmentIntervalMonths = 12
    }
}
