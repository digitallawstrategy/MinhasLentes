import Foundation

/// Formatadores de data/hora centralizados, sempre em português do Brasil e no fuso horário
/// atual do aparelho.
///
/// `DateFormatter` é uma classe não-`Sendable`; isolar este cache ao `MainActor` (onde toda a
/// camada de UI e persistência do app já roda) evita o acesso concorrente não sincronizado que
/// o modo estrito de concorrência do Swift 6.2 rejeitaria.
@MainActor
enum DateFormatting {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    static let shortWithTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return formatter
    }()

    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter
    }()
}
