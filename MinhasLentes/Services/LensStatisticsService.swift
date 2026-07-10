import Foundation

/// Funções puras de cálculo relacionadas ao ciclo de vida de um par de lentes e ao ciclo de
/// limpeza do estojo. Mantidas sem dependência de SwiftData para facilitar testes unitários.
enum LensStatisticsService {

    /// Quantidade de usos válidos registrados para um par.
    static func usesCount(for usages: [LensUsage]) -> Int {
        usages.count
    }

    /// Usos restantes até o limite. Nunca é negativo.
    static func usesRemaining(usesCount: Int, maximumUses: Int) -> Int {
        max(0, maximumUses - usesCount)
    }

    /// Percentual (0...1) da vida útil já utilizada.
    static func lifeUsedFraction(usesCount: Int, maximumUses: Int) -> Double {
        guard maximumUses > 0 else { return 0 }
        return min(1.0, Double(usesCount) / Double(maximumUses))
    }

    static func hasReachedLimit(usesCount: Int, maximumUses: Int) -> Bool {
        usesCount >= maximumUses
    }

    /// Faixa de saúde do par, derivada do percentual de usos restantes e das faixas
    /// configuráveis em `AppSettings`. Um par que já atingiu o limite é sempre `.critical`.
    static func healthStatus(
        usesRemaining: Int,
        maximumUses: Int,
        goodBelowPercent: Int,
        warningBelowPercent: Int,
        criticalBelowPercent: Int
    ) -> LensHealthStatus {
        guard maximumUses > 0, usesRemaining > 0 else { return .critical }
        let remainingPercent = Int((Double(usesRemaining) / Double(maximumUses) * 100).rounded())
        if remainingPercent < criticalBelowPercent { return .critical }
        if remainingPercent < warningBelowPercent { return .warning }
        if remainingPercent < goodBelowPercent { return .good }
        return .excellent
    }

    /// Data da próxima limpeza recomendada, calculada a partir da última limpeza registrada,
    /// usando o calendário e o fuso horário atuais do aparelho. Independe dos usos das lentes.
    static func nextCleaningDate(lastCleaningDate: Date, intervalDays: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: intervalDays, to: calendar.startOfDay(for: lastCleaningDate)) ?? lastCleaningDate
    }

    /// Data do aviso antecipado de limpeza, sempre anterior à data-limite.
    static func advanceReminderDate(lastCleaningDate: Date, intervalDays: Int, advanceDays: Int, calendar: Calendar = .current) -> Date {
        let deadline = nextCleaningDate(lastCleaningDate: lastCleaningDate, intervalDays: intervalDays, calendar: calendar)
        return calendar.date(byAdding: .day, value: -advanceDays, to: deadline) ?? deadline
    }

    /// Verifica se já existe um uso registrado no mesmo dia do calendário (fuso local).
    static func hasUsage(onSameDayAs date: Date, in usages: [LensUsage], calendar: Calendar = .current) -> Bool {
        usages.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
