import Foundation
import SwiftData
@testable import MinhasLentes

/// Utilitários compartilhados pelos testes: criação de contexto SwiftData em memória e
/// construção de datas determinísticas em um fuso horário específico.
enum TestSupport {
    static func makeContext() -> ModelContext {
        let schema = Schema([
            LensPair.self,
            LensUsage.self,
            CaseCleaning.self,
            AppSettings.self,
            HistoryEvent.self,
            LensCase.self,
            RoutineCareLog.self,
            CleaningSolution.self,
            LensInventoryItem.self,
            EyeCareProfessional.self,
            EyeAppointment.self,
            WearSession.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        timeZoneIdentifier: String = "America/Sao_Paulo"
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
