import Foundation

/// Gera um arquivo CSV com o histórico completo (pares, usos e limpezas do estojo) para
/// compartilhamento através da folha nativa do iOS. Opera sobre modelos do SwiftData
/// (`LensPair`, `CaseCleaning`), por isso é isolado ao `MainActor`, como o restante da
/// camada de persistência.
@MainActor
enum CSVExporter {
    enum ExportError: LocalizedError {
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .writeFailed(let detail):
                return "Não foi possível gerar o arquivo CSV. \(detail)"
            }
        }
    }

    static func export(pairs: [LensPair], cleanings: [CaseCleaning]) throws -> URL {
        var lines: [String] = []
        lines.append([
            "Seção", "Par", "Nome", "Início", "Encerramento", "LimiteDeUsos",
            "TotalDeUsos", "UsosRestantes", "NúmeroSequencialDoUso", "DataDoUso",
            "LadoDaLente", "MotivoDoDescarte", "Observações",
        ].joined(separator: ";"))

        for pair in pairs.sorted(by: { $0.sequenceNumber < $1.sequenceNumber }) {
            let usages = pair.sortedUsages.sorted { $0.date < $1.date }
            if usages.isEmpty {
                lines.append(row(section: "Par", pair: pair, usageIndex: nil, usage: nil))
            } else {
                for (index, usage) in usages.enumerated() {
                    lines.append(row(section: "Uso", pair: pair, usageIndex: index + 1, usage: usage))
                }
            }
        }

        lines.append("")
        lines.append(["Seção", "DataDaLimpeza", "Observações"].joined(separator: ";"))
        for cleaning in cleanings.sorted(by: { $0.cleaningDate < $1.cleaningDate }) {
            lines.append([
                "Limpeza",
                DateFormatting.short.string(from: cleaning.cleaningDate),
                csvField(cleaning.notes ?? ""),
            ].joined(separator: ";"))
        }

        let content = lines.joined(separator: "\n")
        return try writeTempFile(content: content, fileExtension: "csv")
    }

    private static func row(section: String, pair: LensPair, usageIndex: Int?, usage: LensUsage?) -> String {
        let fields: [String] = [
            section,
            "Par nº \(pair.sequenceNumber)",
            pair.name,
            DateFormatting.short.string(from: pair.startDate),
            pair.endDate.map { DateFormatting.short.string(from: $0) } ?? "",
            "\(pair.maximumUses)",
            "\(pair.usesCount)",
            "\(pair.usesRemaining)",
            usageIndex.map(String.init) ?? "",
            usage.map { DateFormatting.short.string(from: $0.date) } ?? "",
            usage?.side.displayName ?? pair.side.displayName,
            pair.discardReasonValue?.displayName ?? "",
            usage?.notes ?? pair.notes ?? "",
        ]
        return fields.map(csvField).joined(separator: ";")
    }

    private static func csvField(_ value: String) -> String {
        if value.contains(";") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    static func writeTempFile(content: String, fileExtension: String) throws -> URL {
        let filename = "MinhasLentes_Historico_\(DateFormatting.fileTimestamp.string(from: Date())).\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }
}
