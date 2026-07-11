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

                Spacer()
                Text(monthTitle)
                    .font(.footnote.weight(.semibold))
                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(daysGrid.enumerated()), id: \.offset) { _, date in
                    dayCell(date)
                }
            }

            if !secondaryLoggedDates.isEmpty {
                HStack(spacing: 12) {
                    legendItem(color: AppColor.primary, label: "Cuidado diário")
                    legendItem(color: AppColor.secondary, label: "Limpeza periódica")
                }
                .padding(.top, 2)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            let isLogged = loggedDaySet.contains(calendar.startOfDay(for: date))
            let isSecondaryLogged = secondaryLoggedDaySet.contains(calendar.startOfDay(for: date))
            let isFuture = date > Date()
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(isLogged ? AppColor.primary : Color.clear)
                    .overlay(
                        Circle().strokeBorder(isFuture ? Color.clear : Color.secondary.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 10))
                            .foregroundStyle(isLogged ? Color.white : (isFuture ? Color.secondary.opacity(0.35) : Color.primary))
                    )
                if isSecondaryLogged {
                    Circle()
                        .fill(AppColor.secondary)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(.background, lineWidth: 1))
                }
            }
            .frame(width: 24, height: 24)
        } else {
            Color.clear.frame(width: 24, height: 24)
        }
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
