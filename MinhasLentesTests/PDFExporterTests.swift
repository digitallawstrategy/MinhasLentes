import XCTest
@testable import MinhasLentes

@MainActor
final class PDFExporterTests: XCTestCase {

    func testExportProducesNonEmptyPDFFile() throws {
        let pair = LensPair(
            name: "Par nº 1", sequenceNumber: 1, startDate: TestSupport.date(2026, 7, 10),
            maximumUses: 60, trackingMode: .pair, side: .both
        )
        let usage = LensUsage(date: TestSupport.date(2026, 7, 10), side: .both, lensPair: pair)
        pair.usages = [usage]
        let cleaning = CaseCleaning(cleaningDate: TestSupport.date(2026, 7, 10))

        let url = try PDFExporter.export(pairs: [pair], cleanings: [cleaning])
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertFalse(data.isEmpty)
        // Todo PDF válido começa com a assinatura "%PDF-".
        XCTAssertEqual(data.prefix(5), Data("%PDF-".utf8))
    }
}
