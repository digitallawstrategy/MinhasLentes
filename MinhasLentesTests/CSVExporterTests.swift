import XCTest
import SwiftData
@testable import MinhasLentes

@MainActor
final class CSVExporterTests: XCTestCase {

    func testExportProducesFileWithExpectedContent() throws {
        let context = TestSupport.makeContext()
        let pair = LensPair(
            name: "Par nº 1", sequenceNumber: 1, startDate: TestSupport.date(2026, 7, 10),
            maximumUses: 60, trackingMode: .pair, side: .both
        )
        context.insert(pair)
        let usage = LensUsage(date: TestSupport.date(2026, 7, 10), side: .both, lensPair: pair)
        context.insert(usage)
        let cleaning = CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 10))
        context.insert(cleaning)
        try context.save()

        let url = try CSVExporter.export(pairs: [pair], cleanings: [cleaning])
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("Seção;Par;Nome;Início"))
        XCTAssertTrue(content.contains("Par nº 1"))
        XCTAssertTrue(content.contains("10/07/2026"))
        XCTAssertTrue(content.contains("Limpeza;10/07/2026"))
    }

    func testExportWithoutUsagesStillListsThePair() throws {
        let pair = LensPair(
            name: "Par nº 2", sequenceNumber: 2, startDate: TestSupport.date(2026, 7, 10),
            maximumUses: 60, trackingMode: .pair, side: .both
        )
        let url = try CSVExporter.export(pairs: [pair], cleanings: [])
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("Par;Par nº 2"))
    }
}
