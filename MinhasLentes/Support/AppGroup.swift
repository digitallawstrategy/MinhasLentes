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

    /// Caminho do arquivo SQLite dentro do contêiner do App Group — o store local legado, sem
    /// CloudKit. Nunca migrado/sobrescrito no lugar: continua existindo para sempre como rede de
    /// segurança, mesmo depois que o store com CloudKit (`cloudStoreURL()`) estiver em uso.
    static func storeURL() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw SharedContainerError.containerUnavailable
        }
        return containerURL.appendingPathComponent("MinhasLentes.sqlite")
    }

    /// Caminho do arquivo do store sincronizado por CloudKit — deliberadamente um arquivo NOVO e
    /// separado de `storeURL()`, nunca o mesmo. Ver `CloudSyncMigrationService` e
    /// `AppContainer.attemptCloudMigrationIfNeeded()`: o conteúdo do store legado é copiado para
    /// cá uma vez, o arquivo legado em si nunca é tocado.
    static func cloudStoreURL() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw SharedContainerError.containerUnavailable
        }
        return containerURL.appendingPathComponent("MinhasLentesCloud.sqlite")
    }

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    private static let cloudMigrationCompleteKey = "cloudSyncMigrationComplete"

    /// `true` depois que `CloudSyncMigrationService` copiou o store legado para o store com
    /// CloudKit com sucesso, ao menos uma vez — a partir daí, `AppContainer` passa a abrir o
    /// store com CloudKit na próxima vez que o app iniciar (nunca no meio de uma sessão já em
    /// andamento, ver comentário em `AppContainer.attemptCloudMigrationIfNeeded()`).
    static var isCloudMigrationComplete: Bool {
        get { sharedDefaults.bool(forKey: cloudMigrationCompleteKey) }
        set { sharedDefaults.set(newValue, forKey: cloudMigrationCompleteKey) }
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
