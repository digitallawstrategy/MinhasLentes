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
    }
}
