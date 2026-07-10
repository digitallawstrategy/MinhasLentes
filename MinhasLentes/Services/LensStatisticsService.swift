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

    /// Faixa de status de UTILIZAÇÃO do par (leitura da contagem de usos restantes, não uma
    /// avaliação clínica ou de integridade física), derivada do percentual de usos restantes e
    /// das faixas configuráveis em `AppSettings`. Um par que já atingiu o limite é sempre `.critical`.
    static func usageStatus(
        usesRemaining: Int,
        maximumUses: Int,
        goodBelowPercent: Int,
        warningBelowPercent: Int,
        criticalBelowPercent: Int
    ) -> LensUsageStatus {
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

    /// Data do aviso antecipado de limpeza, sempre anterior à data-limite. A antecedência é
    /// sempre restringida a `0..<intervalDays`, mesmo que o valor salvo em `AppSettings` esteja
    /// desatualizado (ex.: intervalo reduzido depois da antecedência ter sido definida) — nunca
    /// cai antes do ciclo de limpeza anterior.
    static func advanceReminderDate(lastCleaningDate: Date, intervalDays: Int, advanceDays: Int, calendar: Calendar = .current) -> Date {
        let deadline = nextCleaningDate(lastCleaningDate: lastCleaningDate, intervalDays: intervalDays, calendar: calendar)
        let clampedAdvance = min(max(advanceDays, 0), max(intervalDays - 1, 0))
        return calendar.date(byAdding: .day, value: -clampedAdvance, to: deadline) ?? deadline
    }

    /// Verifica se já existe um uso registrado no mesmo dia do calendário (fuso local).
    static func hasUsage(onSameDayAs date: Date, in usages: [LensUsage], calendar: Calendar = .current) -> Bool {
        usages.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
