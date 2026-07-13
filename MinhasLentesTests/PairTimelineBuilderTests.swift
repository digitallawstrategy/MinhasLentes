import XCTest
@testable import MinhasLentes

final class PairTimelineBuilderTests: XCTestCase {

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

        let entries = PairTimelineBuilder.build(pair: pair, allCleanings: [cleaning], warningBelowPercent: 40)

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

        let entries = PairTimelineBuilder.build(pair: pair, allCleanings: [before, during], warningBelowPercent: 40)

        XCTAssertEqual(entries.filter { $0.title == "Estojo limpo" }.count, 1)
    }

    func testEntryKindsMatchTheirEventType() {
        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 10,
            trackingMode: .pair,
            side: .both
        )
        pair.usages = [LensUsage(date: TestSupport.date(2026, 7, 2), side: .both, lensPair: pair)]
        pair.status = .finished
        pair.endDate = TestSupport.date(2026, 7, 5)

        let cleaning = CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 3))
        let event = HistoryEvent(eventType: .pairEdited, eventDate: TestSupport.date(2026, 7, 4), lensPairID: pair.id, descriptionText: "Nome alterado")

        let entries = PairTimelineBuilder.build(pair: pair, allCleanings: [cleaning], warningBelowPercent: 40, events: [event])

        XCTAssertEqual(entries.first { $0.title == "Par iniciado" }?.kind, .start)
        XCTAssertEqual(entries.first { $0.title == "Uso nº 1" }?.kind, .usage)
        XCTAssertEqual(entries.first { $0.title == "Estojo limpo" }?.kind, .cleaning)
        XCTAssertEqual(entries.first { $0.title == "Par editado" }?.kind, .edit)
        XCTAssertEqual(entries.first { $0.title == "Par substituído" }?.kind, .end)
    }

    func testSessionStartedEntryAppearsForActiveSession() {
        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 10,
            trackingMode: .pair,
            side: .both
        )
        let session = WearSession(startedAt: TestSupport.date(2026, 7, 2), lensPair: pair)
        pair.wearSessions = [session]

        let entries = PairTimelineBuilder.build(pair: pair, allCleanings: [], warningBelowPercent: 40)

        XCTAssertTrue(entries.contains { $0.title == "Sessão iniciada" && $0.kind == .session })
        XCTAssertFalse(entries.contains { $0.title == "Sessão finalizada" }, "Sem endedAt, não deve haver entrada de finalização")
    }

    func testSessionFinishedEntryOnlyAppearsWithEndedAtAndIncludesDuration() {
        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 10,
            trackingMode: .pair,
            side: .both
        )
        let session = WearSession(startedAt: TestSupport.date(2026, 7, 2, hour: 8), lensPair: pair)
        session.endedAt = TestSupport.date(2026, 7, 2, hour: 10)
        pair.wearSessions = [session]

        let entries = PairTimelineBuilder.build(pair: pair, allCleanings: [], warningBelowPercent: 40)

        let finished = entries.first { $0.title == "Sessão finalizada" }
        XCTAssertNotNil(finished)
        XCTAssertEqual(finished?.kind, .session)
        XCTAssertTrue(finished?.subtitle?.contains("Duração") ?? false)
    }

    func testEventsFromAnotherPairAreExcluded() {
        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 10,
            trackingMode: .pair,
            side: .both
        )
        let otherPairEvent = HistoryEvent(eventType: .pairEdited, eventDate: TestSupport.date(2026, 7, 2), lensPairID: UUID(), descriptionText: "Outro par")

        let entries = PairTimelineBuilder.build(pair: pair, allCleanings: [], warningBelowPercent: 40, events: [otherPairEvent])

        XCTAssertFalse(entries.contains { $0.title == "Par editado" }, "Evento de outro par não deve aparecer na linha do tempo")
    }

    func testStartedAndFinishedEventTypesAreIgnoredToAvoidDuplication() {
        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: TestSupport.date(2026, 7, 1),
            maximumUses: 10,
            trackingMode: .pair,
            side: .both
        )
        let startedEvent = HistoryEvent(eventType: .pairStarted, eventDate: TestSupport.date(2026, 7, 1), lensPairID: pair.id, descriptionText: "Par iniciado")
        let finishedEvent = HistoryEvent(eventType: .pairFinished, eventDate: TestSupport.date(2026, 7, 5), lensPairID: pair.id, descriptionText: "Par finalizado")

        let entries = PairTimelineBuilder.build(pair: pair, allCleanings: [], warningBelowPercent: 40, events: [startedEvent, finishedEvent])

        XCTAssertEqual(entries.filter { $0.kind == .start }.count, 1, "pairStarted do feed de eventos não deve duplicar a entrada de início")
        XCTAssertEqual(entries.filter { $0.kind == .end }.count, 0, "Par ainda não está finished/endDate — não deve haver entrada de fim")
    }

    func testGroupedByMonthBucketsSameMonthAndSeparatesDifferentMonths() {
        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: TestSupport.date(2026, 6, 15),
            maximumUses: 10,
            trackingMode: .pair,
            side: .both
        )
        pair.usages = [
            LensUsage(date: TestSupport.date(2026, 6, 20), side: .both, lensPair: pair),
            LensUsage(date: TestSupport.date(2026, 7, 5), side: .both, lensPair: pair)
        ]

        let entries = PairTimelineBuilder.build(pair: pair, allCleanings: [], warningBelowPercent: 40)
        let groups = PairTimelineBuilder.groupedByMonth(entries)

        XCTAssertEqual(groups.count, 2, "Junho e julho devem formar dois grupos separados")
        XCTAssertEqual(groups[0].entries.count, 2, "Início do par + uso de junho no mesmo grupo")
        XCTAssertEqual(groups[1].entries.count, 1)
    }

    func testFilterCategoriesMatchExpectedKinds() {
        XCTAssertTrue(PairTimelineFilter.all.matches(.usage))
        XCTAssertTrue(PairTimelineFilter.all.matches(.cleaning))

        XCTAssertTrue(PairTimelineFilter.usage.matches(.usage))
        XCTAssertTrue(PairTimelineFilter.usage.matches(.warning))
        XCTAssertFalse(PairTimelineFilter.usage.matches(.session))

        XCTAssertTrue(PairTimelineFilter.session.matches(.session))
        XCTAssertFalse(PairTimelineFilter.session.matches(.usage))

        XCTAssertTrue(PairTimelineFilter.cleaning.matches(.cleaning))
        XCTAssertFalse(PairTimelineFilter.cleaning.matches(.edit))

        XCTAssertTrue(PairTimelineFilter.event.matches(.start))
        XCTAssertTrue(PairTimelineFilter.event.matches(.edit))
        XCTAssertTrue(PairTimelineFilter.event.matches(.end))
        XCTAssertFalse(PairTimelineFilter.event.matches(.usage))
    }
}
