import XCTest
@testable import MinhasLentes

final class PairDiaryBuilderTests: XCTestCase {

    func testBuildsChronologicalEntriesWithWarningAndReplacement() {
        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: TestSupport.date(2026, 7, 10),
            maximumUses: 4,
            trackingMode: .pair,
            side: .both
        )
        let usages = [
            LensUsage(date: TestSupport.date(2026, 7, 11), side: .both, lensPair: pair),
            LensUsage(date: TestSupport.date(2026, 7, 12), side: .both, lensPair: pair),
            LensUsage(date: TestSupport.date(2026, 7, 13), side: .both, lensPair: pair)
        ]
        pair.usages = usages
        pair.status = .finished
        pair.endDate = TestSupport.date(2026, 7, 20)
        pair.discardReasonValue = .damaged

        let cleaning = CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 12))

        let entries = PairDiaryBuilder.build(pair: pair, allCleanings: [cleaning], warningBelowPercent: 40)

        XCTAssertEqual(entries.first?.title, "Par iniciado")
        XCTAssertEqual(entries.last?.title, "Par substituído")

        let dates = entries.map(\.date)
        XCTAssertEqual(dates, dates.sorted(), "As entradas devem estar em ordem cronológica")

        XCTAssertTrue(entries.contains { $0.title == "Uso nº 1" })
        XCTAssertTrue(entries.contains { $0.title == "Uso nº 3" })
        XCTAssertTrue(entries.contains { $0.title == "Estojo limpo" })
        // 3º uso deixa 1 restante de 4 (25%), abaixo dos 40% configurados — deve cruzar o aviso.
        XCTAssertTrue(entries.contains { $0.title.hasPrefix("Restam") })
    }

    func testExcludesCleaningsOutsidePairPeriod() {
        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: TestSupport.date(2026, 7, 10),
            maximumUses: 60,
            trackingMode: .pair,
            side: .both
        )
        let before = CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 1))
        let during = CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 15))

        let entries = PairDiaryBuilder.build(pair: pair, allCleanings: [before, during], warningBelowPercent: 40)

        XCTAssertEqual(entries.filter { $0.title == "Estojo limpo" }.count, 1)
    }
}
