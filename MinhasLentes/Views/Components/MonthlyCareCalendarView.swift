import SwiftUI

/// Calendário mensal compacto de hábito: marca os dias em que houve um registro de cuidado
/// diário (círculo preenchido) e, quando informado, também os dias com limpeza periódica do
/// estojo (marcador pequeno) — dois conceitos que nunca se misturam nos dados (ver
/// `RoutineCareLog`/`CaseCleaning`), mas que fazem sentido de ver lado a lado num único
/// calendário, já que os dois botões de registro ficam na mesma tela e é fácil confundir qual
/// usar no dia a dia. Deixa sem marcar os dias que passaram sem nenhum registro — sem tentar
/// adivinhar se foi esquecimento ou simplesmente um dia sem uso das lentes. Navegação limitada
/// ao passado (não faz sentido "marcar" um dia que ainda não aconteceu).
struct MonthlyCareCalendarView: View {
    let loggedDates: [Date]
    var secondaryLoggedDates: [Date] = []

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())

    private var calendar: Calendar { Calendar.current }
    private var loggedDaySet: Set<Date> {
        LensStatisticsService.calendarDaySet(from: loggedDates, calendar: calendar)
    }
    private var secondaryLoggedDaySet: Set<Date> {
        LensStatisticsService.calendarDaySet(from: secondaryLoggedDates, calendar: calendar)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMMM 'de' yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.veryShortStandaloneWeekdaySymbols ?? ["D", "S", "T", "Q", "Q", "S", "S"]
    }

    /// `nil` representa uma célula vazia antes do dia 1 do mês, para alinhar a grade nas colunas
    /// corretas de dia da semana.
    private var daysGrid: [Date?] {
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
            let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let leadingEmptyCount = calendar.component(.weekday, from: monthStart) - 1
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyCount)
        days.append(contentsOf: range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) })
        return days
    }

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mês anterior")

                Spacer()
                Text(monthTitle)
                    .font(AppTypography.footnote.weight(.semibold))
                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
                .accessibilityLabel("Próximo mês")
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(daysGrid.enumerated()), id: \.offset) { _, date in
                    dayCell(date)
                }
            }

            if !secondaryLoggedDates.isEmpty {
                HStack(spacing: 14) {
                    legendItem(color: AppColor.primary, label: "Cuidado diário")
                    legendItem(color: AppColor.secondary, label: "Limpeza periódica")
                }
                .padding(.top, 4)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // 32pt (não 24pt): o calendário é um dos elementos mais olhados de um app de rotina diária —
    // números pequenos demais o deixavam funcional, mas esquecível. Tamanho fixo, não relativo a
    // Dynamic Type: numa grade de 7 colunas, deixar a célula crescer com a fonte do sistema
    // estouraria a largura da tela em vez de ficar mais legível (mesmo raciocínio de
    // `UsageCountRing`).
    private let cellSize: CGFloat = 32

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            let isLogged = loggedDaySet.contains(calendar.startOfDay(for: date))
            let isSecondaryLogged = secondaryLoggedDaySet.contains(calendar.startOfDay(for: date))
            let isFuture = date > Date()
            let isToday = calendar.isDateInToday(date)
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(isLogged ? AppColor.primary : Color.clear)
                    .overlay(
                        // Hoje sempre ganha um contorno na cor da marca, registrado ou não — sem
                        // isso, "onde estou no mês" só dava para saber contando os dias.
                        Circle().strokeBorder(
                            isToday ? AppColor.primary : (isFuture ? Color.clear : Color.secondary.opacity(0.4)),
                            lineWidth: isToday ? 1.5 : 1
                        )
                    )
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 13, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isLogged ? Color.white : (isFuture ? Color.secondary.opacity(0.4) : Color.primary))
                    )
                if isSecondaryLogged {
                    Circle()
                        .fill(AppColor.secondary)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
                }
            }
            .frame(width: cellSize, height: cellSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(dayAccessibilityLabel(date))
            .accessibilityValue(dayAccessibilityValue(isLogged: isLogged, isSecondaryLogged: isSecondaryLogged, isFuture: isFuture, isToday: isToday))
        } else {
            Color.clear.frame(width: cellSize, height: cellSize)
                .accessibilityHidden(true)
        }
    }

    /// Dia + mês por extenso — o mês exibido já dá contexto suficiente sem precisar repetir o
    /// ano em toda célula.
    private func dayAccessibilityLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d 'de' MMMM"
        return formatter.string(from: date)
    }

    /// Cor sozinha nunca é a única forma de saber se um dia tem registro, nem se é hoje — isto é
    /// o equivalente em texto do preenchimento/contorno/marcador que a célula já mostra
    /// visualmente.
    private func dayAccessibilityValue(isLogged: Bool, isSecondaryLogged: Bool, isFuture: Bool, isToday: Bool) -> String {
        if isFuture { return "Dia futuro" }
        var parts: [String] = []
        if isToday { parts.append("Hoje") }
        if isLogged { parts.append("Cuidado diário registrado") }
        if isSecondaryLogged { parts.append("Limpeza periódica registrada") }
        return parts.isEmpty ? "Sem registro" : parts.joined(separator: ", ")
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = min(newMonth, Calendar.current.startOfDay(for: Date()))
    }
}

#Preview {
    MonthlyCareCalendarView(
        loggedDates: [
            Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -4, to: Date())!,
        ],
        secondaryLoggedDates: [
            Calendar.current.date(byAdding: .day, value: -4, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -12, to: Date())!,
        ]
    )
    .padding()
}
