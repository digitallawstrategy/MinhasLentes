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

    /// Após quantas horas de sessão "Estou usando as lentes" o lembrete de remoção é enviado.
    var wearingReminderHours: Int = 8

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
    }
}
