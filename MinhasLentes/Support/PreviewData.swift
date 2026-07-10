import Foundation
import SwiftData

/// Fornece um `ModelContainer` em memória com dados de demonstração, usado exclusivamente
/// pelas Previews do Xcode (`#Preview`). Nunca é referenciado pelo fluxo real do aplicativo,
/// que sempre parte de um armazenamento vazio na primeira execução.
enum PreviewData {
    @MainActor static var container: ModelContainer = {
        let schema = Schema([
            LensPair.self,
            LensUsage.self,
            CaseCleaning.self,
            AppSettings.self,
            HistoryEvent.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10)) ?? Date()

        let settings = AppSettings()
        context.insert(settings)

        let pair = LensPair(
            name: "Par nº 1",
            sequenceNumber: 1,
            startDate: startDate,
            maximumUses: 60,
            trackingMode: .pair,
            side: .both
        )
        context.insert(pair)

        let usage = LensUsage(date: startDate, side: .both, lensPair: pair)
        context.insert(usage)

        let cleaning = CaseCleaning(cleaningDate: startDate)
        context.insert(cleaning)

        try? context.save()
        return container
    }()
}
