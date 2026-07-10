import Foundation
import SwiftData

/// Garante que exista sempre uma única instância persistida de `AppSettings`.
@MainActor
enum AppSettingsStore {
    enum StoreError: LocalizedError {
        case persistenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .persistenceFailed(let detail):
                return "Não foi possível preparar o armazenamento local das configurações. \(detail)"
            }
        }
    }

    static func currentSettings(context: ModelContext) throws -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        do {
            if let existing = try context.fetch(descriptor).first {
                return existing
            }
        } catch {
            throw StoreError.persistenceFailed(error.localizedDescription)
        }
        let settings = AppSettings()
        context.insert(settings)
        do {
            try context.save()
        } catch {
            throw StoreError.persistenceFailed(error.localizedDescription)
        }
        return settings
    }
}
