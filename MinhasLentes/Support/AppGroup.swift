import Foundation

/// Identificador do App Group compartilhado entre o app e o widget/Live Activity, usado para
/// que os dois processos leiam o mesmo banco do SwiftData.
///
/// Este arquivo pertence tanto ao target do app quanto ao da extensão de widget (target
/// membership dupla) — é o único jeito de compartilhar os tipos `@Model` entre processos
/// diferentes sem duplicar código.
enum AppGroup {
    static let identifier = "group.com.raonny.minhaslentes"

    enum SharedContainerError: LocalizedError {
        case containerUnavailable

        var errorDescription: String? {
            "Não foi possível acessar o armazenamento compartilhado do App Group."
        }
    }

    /// Caminho do arquivo SQLite dentro do contêiner do App Group.
    static func storeURL() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw SharedContainerError.containerUnavailable
        }
        return containerURL.appendingPathComponent("MinhasLentes.sqlite")
    }

    /// Migra silenciosamente, uma única vez, um banco criado antes deste app ter um App Group
    /// (armazenado no contêiner privado do app) para o contêiner compartilhado — para que
    /// instalações existentes não "percam" os dados ao atualizar para a versão com widget.
    static func migrateLegacyStoreIfNeeded(to destination: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path) else { return }
        guard let legacyDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let legacyStore = legacyDirectory.appendingPathComponent("default.store")
        guard fileManager.fileExists(atPath: legacyStore.path) else { return }

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacyStore.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = URL(fileURLWithPath: destination.path + suffix)
            try? fileManager.copyItem(at: source, to: target)
        }
    }
}
