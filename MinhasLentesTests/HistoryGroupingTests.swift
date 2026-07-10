import XCTest
@testable import MinhasLentes

final class HistoryGroupingTests: XCTestCase {

    func testGroupsIntoTodayYesterdayWeekMonthAndOlder() {
        let calendar = Calendar.current
        let now = TestSupport.date(2026, 7, 20, hour: 12)

        func item(_ label: String, daysAgo: Int) -> HistoryItem {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            let cleaning = CaseCleaning(cleaningDate: date)
            return HistoryItem(id: label, date: date, kind: .cleaning(cleaning))
        }

        let items = [
            item("today", daysAgo: 0),
            item("yesterday", daysAgo: 1),
            item("thisWeek", daysAgo: 4),
            item("thisMonth", daysAgo: 15),
            item("older", daysAgo: 400)
        ]

        let sections = HistoryGrouping.group(items, now: now, calendar: calendar)
        let titles = sections.map(\.title)

        XCTAssertEqual(titles, ["Hoje", "Ontem", "Esta semana", "Este mês", "Mais antigos"])
        XCTAssertEqual(sections.first?.items.first?.id, "today")
    }

    func testEmptyInputProducesNoSections() {
        XCTAssertTrue(HistoryGrouping.group([]).isEmpty)
    }
}
