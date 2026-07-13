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

    /// Dia+mês e hora, sem ano — para linhas de lista já agrupadas por período (Histórico): o
    /// ano quase sempre é o atual e "às" só ocupa espaço numa linha que já precisa caber
    /// tipo + dia + lado, então sai daqui, ficando só "dd/MM, HH:mm".
    static let shortWithTimeCompact: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM, HH:mm"
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

    /// Formata uma duração como "08h 17min" — usado na Dynamic Island e no histórico de
    /// sessões de uso. Nunca negativo, mesmo que `duration` chegue levemente abaixo de zero por
    /// imprecisão de ponto flutuante.
    static func durationShort(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02dh %02dmin", hours, minutes)
    }
}
