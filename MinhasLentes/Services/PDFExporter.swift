import Foundation
import UIKit

/// Gera um relatório em PDF com o histórico completo, usando apenas `UIGraphicsPDFRenderer`
/// (API nativa do iOS, sem dependências externas). Opera sobre modelos do SwiftData, por isso
/// é isolado ao `MainActor`.
@MainActor
enum PDFExporter {
    enum ExportError: LocalizedError {
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .writeFailed(let detail):
                return "Não foi possível gerar o arquivo PDF. \(detail)"
            }
        }
    }

    private static let pageWidth: CGFloat = 595.2
    private static let pageHeight: CGFloat = 841.8
    private static let margin: CGFloat = 36

    static func export(pairs: [LensPair], cleanings: [CaseCleaning]) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let headingFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 10)

        let filename = "MinhasLentes_Historico_\(DateFormatting.fileTimestamp.string(from: Date())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let contentWidth = pageWidth - margin * 2

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y = drawText(
                    "Minhas Lentes — Histórico Completo",
                    font: titleFont,
                    at: CGPoint(x: margin, y: margin),
                    width: contentWidth
                )
                y = drawText(
                    "Gerado em \(DateFormatting.shortWithTime.string(from: Date()))",
                    font: bodyFont,
                    at: CGPoint(x: margin, y: y + 2),
                    width: contentWidth,
                    color: .darkGray
                ) + 14

                for pair in pairs.sorted(by: { $0.sequenceNumber < $1.sequenceNumber }) {
                    if y > pageHeight - margin - 80 {
                        context.beginPage()
                        y = margin
                    }
                    y = drawText(
                        "\(pair.name) (nº \(pair.sequenceNumber) — \(pair.side.displayName))",
                        font: headingFont,
                        at: CGPoint(x: margin, y: y),
                        width: contentWidth
                    ) + 2

                    var info = "Início: \(DateFormatting.short.string(from: pair.startDate))"
                    if let end = pair.endDate {
                        info += "   •   Encerrado: \(DateFormatting.short.string(from: end))"
                    }
                    info += "   •   Limite: \(pair.maximumUses)   •   Usos: \(pair.usesCount)   •   Restantes: \(pair.usesRemaining)"
                    if let reason = pair.discardReasonValue {
                        info += "   •   Motivo: \(reason.displayName)"
                    }
                    if let notes = pair.notes, !notes.isEmpty {
                        info += "   •   Obs.: \(notes)"
                    }
                    y = drawText(info, font: bodyFont, at: CGPoint(x: margin, y: y), width: contentWidth) + 4

                    let usages = pair.sortedUsages.sorted { $0.date < $1.date }
                    if usages.isEmpty {
                        y = drawText("Nenhum uso registrado.", font: bodyFont, at: CGPoint(x: margin, y: y), width: contentWidth, color: .darkGray) + 10
                    } else {
                        let usageList = usages.enumerated().map { index, usage in
                            "\(index + 1)) \(DateFormatting.short.string(from: usage.date)) [\(usage.side.displayName)]"
                        }.joined(separator: "   ")

                        if y > pageHeight - margin - 60 {
                            context.beginPage()
                            y = margin
                        }
                        y = drawText(usageList, font: bodyFont, at: CGPoint(x: margin, y: y), width: contentWidth) + 12
                    }
                }

                if y > pageHeight - margin - 100 {
                    context.beginPage()
                    y = margin
                }
                y = drawText("Limpezas do estojo", font: headingFont, at: CGPoint(x: margin, y: y + 6), width: contentWidth) + 4

                let sortedCleanings = cleanings.sorted { $0.cleaningDate < $1.cleaningDate }
                if sortedCleanings.isEmpty {
                    y = drawText("Nenhuma limpeza registrada.", font: bodyFont, at: CGPoint(x: margin, y: y), width: contentWidth, color: .darkGray)
                } else {
                    let cleaningList = sortedCleanings.map { DateFormatting.short.string(from: $0.cleaningDate) }.joined(separator: "   •   ")
                    y = drawText(cleaningList, font: bodyFont, at: CGPoint(x: margin, y: y), width: contentWidth)
                }
                _ = y
            }
            return url
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }

    @discardableResult
    private static func drawText(_ text: String, font: UIFont, at point: CGPoint, width: CGFloat, color: UIColor = .black) -> CGFloat {
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let bounding = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        )
        let height = bounding.height.rounded(.up)
        attributed.draw(with: CGRect(x: point.x, y: point.y, width: width, height: height), options: [.usesLineFragmentOrigin], context: nil)
        return point.y + height + 2
    }
}
