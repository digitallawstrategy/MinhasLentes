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

    /// Dias corridos entre `date` e `referenceDate` (positivo se `date` for no passado).
    /// Compartilhado entre a aba Estojo, o cartão compacto da Home e o widget, para as três
    /// apresentações concordarem sempre no mesmo número.
    static func daysSince(_ date: Date, referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: referenceDate)).day ?? 0
    }

    /// Dias corridos entre `referenceDate` e `date` (positivo se `date` for no futuro).
    static func daysUntil(_ date: Date, referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: referenceDate), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// Data recomendada para substituição do estojo, calculada a partir do início do ciclo
    /// atual — independe de quantas limpezas (periódicas ou de rotina) aconteceram nesse meio-tempo.
    static func nextCaseReplacementDate(startDate: Date, intervalDays: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: intervalDays, to: calendar.startOfDay(for: startDate)) ?? startDate
    }

    /// Data de descarte de uma solução de limpeza aberta: sempre a menor entre a validade
    /// pós-abertura (contada a partir de `openedDate`) e a validade impressa pelo fabricante,
    /// quando informada. Nunca inventa um prazo médico universal — os dois valores vêm sempre
    /// do próprio produto.
    static func solutionDiscardDate(
        openedDate: Date,
        postOpeningShelfLifeDays: Int,
        printedExpiryDate: Date?,
        calendar: Calendar = .current
    ) -> Date {
        let shelfLifeDate = calendar.date(byAdding: .day, value: postOpeningShelfLifeDays, to: calendar.startOfDay(for: openedDate)) ?? openedDate
        guard let printedExpiryDate else { return shelfLifeDate }
        return min(shelfLifeDate, printedExpiryDate)
    }

    /// Reduz uma lista de datas de registro a um conjunto de "dias do calendário" (início do
    /// dia, no fuso informado), para que marcar um dia no calendário de hábito seja uma simples
    /// verificação de pertencimento a um `Set`, sem comparar horários.
    ///
    /// Usa `Date` (início do dia), não `DateComponents` — a igualdade de `DateComponents` pode
    /// levar em conta campos incidentalmente preenchidos além dos pedidos (ex.: `calendar`),
    /// fazendo duas instâncias que representam o mesmo dia não baterem. `Date` compara só o
    /// instante exato, sem essa ambiguidade.
    static func calendarDaySet(from dates: [Date], calendar: Calendar = .current) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }
}
